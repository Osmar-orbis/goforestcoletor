// Todas as importações ficam juntas no topo do arquivo
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {Stripe} from "stripe";

// Inicializa o Firebase Admin (deve ser chamado apenas uma vez)
admin.initializeApp();

// =================== FUNÇÃO 1: CRIAR CLIENTE NO TRIAL ===================
// (Esta função está correta e não precisa de alterações)
export const criarClienteParaNovoUsuario = functions
  .region("southamerica-east1")
  .auth.user().onCreate(async (user) => {
    const email = user.email;
    const uid = user.uid;
    if (!email) {
      console.error("Usuário criado sem email:", uid);
      return null;
    }
    const dataFim = new Date();
    dataFim.setDate(dataFim.getDate() + 15);
    const novoClienteData = {
      planoId: "trial",
      statusAssinatura: "trial",
      usuariosPermitidos: [email],
      features: { analise: false, exportacao: false },
      limites: { smartphone: 1, desktop: 0 },
      trial: { ativo: true, dataFim: admin.firestore.Timestamp.fromDate(dataFim) },
    };
    try {
      await admin.firestore().collection("clientes").doc(uid).set(novoClienteData);
      console.log(`Documento de cliente (Trial) para ${email} criado com sucesso!`);
      return null;
    } catch (error) {
      console.error(`Erro ao criar documento de cliente para ${email}:`, error);
      return null;
    }
  });

// =================== FUNÇÃO 2: CRIAR SESSÃO DE CHECKOUT ===================

// ****** CORREÇÃO APLICADA AQUI ******
// Inicializa o cliente do Stripe buscando a chave das configurações seguras do Firebase
const stripeClient = new Stripe(functions.config().stripe.secret_key, {
  apiVersion: "2024-06-20",
});

export const createCheckoutSession = functions
  .region("southamerica-east1")
  .https.onCall(async (data, context  ) => {
    if (!context.auth) {
      throw new functions.https.HttpsError("unauthenticated", "A função deve ser chamada por um usuário autenticado."  );
    }

    const uid = context.auth.uid;
    const priceId = data.priceId as string;

    if (!priceId) {
      throw new functions.https.HttpsError("invalid-argument", "O ID do preço (priceId ) não foi fornecido.");
    }

    try {
      const firestore = admin.firestore();
      const userDocRef = firestore.collection("clientes").doc(uid);
      const userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Documento do cliente não encontrado."  );
      }

      const userData = userDoc.data()!;
      let customerId = userData.stripeId;

      if (!customerId) {
        const customer = await stripeClient.customers.create({
          email: context.auth.token.email,
          metadata: { firebaseUID: uid },
        });
        customerId = customer.id;
        await userDocRef.update({ stripeId: customerId });
      }

      const ephemeralKey = await stripeClient.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: "2024-06-20" }
      );

      const price = await stripeClient.prices.retrieve(priceId);
      if (!price || !price.unit_amount) {
          throw new functions.https.HttpsError("not-found", "Preço não encontrado no Stripe."  );
      }

      const paymentIntent = await stripeClient.paymentIntents.create({
        amount: price.unit_amount,
        currency: "brl",
        customer: customerId,
        metadata: {
            firebaseUID: uid,
            priceId: priceId,
        },
      });

      if (!paymentIntent.client_secret) {
        throw new functions.https.HttpsError("internal", "Falha ao obter o client_secret do Payment Intent."  );
      }

      return {
        paymentIntent: paymentIntent.client_secret,
        ephemeralKey: ephemeralKey.secret,
        customer: customerId,
        publishableKey: functions.config().stripe.publishable_key,
      };

    } catch (error: any) {
      console.error("Erro do Stripe ao criar sessão de checkout:", error.message);
      throw new functions.https.HttpsError("internal", "Falha ao iniciar a sessão de pagamento."  );
    }
  });


// =================== FUNÇÃO 3: WEBHOOK DO STRIPE ===================
// (Esta função está correta e não precisa de alterações)
export const stripeWebhook = functions
    .region("southamerica-east1")
    .https.onRequest(async (req, res ) => {
        const sig = req.headers["stripe-signature"] as string;
        const endpointSecret = functions.config().stripe.webhook_secret;
        let event: Stripe.Event;

        try {
            event = stripeClient.webhooks.constructEvent(req.rawBody, sig, endpointSecret);
        } catch (err: any) {
            console.error("⚠️ Erro na verificação da assinatura do webhook:", err.message);
            res.status(400).send(`Webhook Error: ${err.message}`);
            return;
        }

        if (event.type === "invoice.payment_succeeded") {
            const invoice = event.data.object as Stripe.Invoice;
            const customerId = invoice.customer as string;
            const priceId = invoice.lines.data[0].price?.id;

            const customer = await stripeClient.customers.retrieve(customerId) as Stripe.Customer;
            const uid = customer.metadata.firebaseUID;

            if (!uid || !priceId) {
                console.error("Erro: UID ou PriceID não encontrados no evento de fatura.");
                return res.status(400).send("Dados insuficientes no evento.");
            }

            console.log(`Pagamento bem-sucedido para UID: ${uid}. Buscando plano para o priceId: ${priceId}`);

            try {
                const planosRef = admin.firestore().collection("planosDeLicenca");
                const planoSnapshotMensal = await planosRef.where("stripePriceIds.mensal", "==", priceId).limit(1).get();
                const planoSnapshotAnual = await planosRef.where("stripePriceIds.anual", "==", priceId).limit(1).get();

                const planoSnapshot = planoSnapshotMensal.empty ? planoSnapshotAnual : planoSnapshotMensal;
                
                if (planoSnapshot.empty) {
                    throw new Error(`Nenhum plano encontrado no Firestore para o priceId: ${priceId}`);
                }

                const planoData = planoSnapshot.docs[0].data();
                const planoId = planoSnapshot.docs[0].id;

                const dadosAtualizacao = {
                    statusAssinatura: "ativa",
                    planoId: planoId,
                    limites: planoData.limites,
                    features: planoData.features,
                    "trial.ativo": false,
                };

                const clienteRef = admin.firestore().collection("clientes").doc(uid);
                await clienteRef.update(dadosAtualizacao);
                
                console.log(`Assinatura do plano '${planoId}' para UID: ${uid} ativada com sucesso.`);
            } catch (error) {
                console.error(`Falha ao atualizar o documento para o UID: ${uid}`, error);
                return res.status(500).send("Erro interno ao atualizar a assinatura.");
            }
        }
        
        res.status(200).send({ received: true });
    });