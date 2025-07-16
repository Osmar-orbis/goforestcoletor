// Todas as importações ficam juntas no topo do arquivo
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {Stripe} from "stripe";

// Inicializa o Firebase Admin (deve ser chamado apenas uma vez)
admin.initializeApp();

// =================== FUNÇÃO 1: CRIAR CLIENTE NO TRIAL ===================
// (Esta função já está correta e não foi alterada)
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
    dataFim.setDate(dataFim.getDate() + 7);
    const novoClienteData = {
      planoId: "trial",
      statusAssinatura: "trial",
      usuariosPermitidos: [email],
      features: {
        analise: true,
        exportacao: false,
      },
      limites: {
        smartphone: 1,
        desktop: 0,
      },
      trial: {
        ativo: true,
        dataFim: admin.firestore.Timestamp.fromDate(dataFim),
      },
    };
    try {
      await admin.firestore().collection("clientes").doc(uid).set(novoClienteData);
      console.log(`Documento de cliente (Trial de 7 dias) para ${email} criado com sucesso!`);
      return null;
    } catch (error) {
      console.error(`Erro ao criar documento de cliente para ${email}:`, error);
      return null;
    }
  });

// =================== FUNÇÃO 2: CRIAR SESSÃO DE CHECKOUT (COM LOGS) ATUALIZADO 16/07 ===================

const stripeClient = new Stripe(functions.config().stripe.secret_key, {
  apiVersion: "2024-06-20",
});

export const createCheckoutSession = functions
  .region("southamerica-east1")
  .https.onCall(async (data, context) => {
    // LOG 1: Função foi chamada
    console.log("Função 'createCheckoutSession' iniciada.");

    if (!context.auth) {
      console.error("ERRO: Usuário não autenticado.");
      throw new functions.https.HttpsError("unauthenticated", "A função deve ser chamada por um usuário autenticado.");
    }

    const uid = context.auth.uid;
    const priceId = data.priceId as string;

    // LOG 2: Verificando dados recebidos
    console.log(`Recebido pedido para UID: ${uid}, Price ID: ${priceId}`);

    if (!priceId) {
      console.error("ERRO: Price ID não fornecido na chamada.");
      throw new functions.https.HttpsError("invalid-argument", "O ID do preço (priceId) não foi fornecido.");
    }

    try {
      const firestore = admin.firestore();
      const userDocRef = firestore.collection("clientes").doc(uid);
      const userDoc = await userDocRef.get();

      if (!userDoc.exists) {
        console.error(`ERRO: Documento do cliente não encontrado para o UID: ${uid}`);
        throw new functions.https.HttpsError("not-found", "Documento do cliente não encontrado.");
      }

      // LOG 3: Documento do cliente foi encontrado
      console.log(`Documento do cliente para UID: ${uid} encontrado.`);

      const userData = userDoc.data()!;
      let customerId = userData.stripeId;

      if (!customerId) {
        // LOG 4: Cliente Stripe não existe, criando um novo.
        console.log(`Cliente Stripe (stripeId) não encontrado para ${uid}. Criando um novo...`);
        const customer = await stripeClient.customers.create({
          email: context.auth.token.email,
          metadata: { firebaseUID: uid },
        });
        customerId = customer.id;
        await userDocRef.update({ stripeId: customerId });
        console.log(`Novo cliente Stripe criado e salvo no Firestore. ID: ${customerId}`);
      } else {
        // LOG 4 (alternativo): Cliente Stripe já existe.
        console.log(`Cliente Stripe (stripeId) encontrado: ${customerId}`);
      }

      // LOG 5: Criando Ephemeral Key
      console.log(`Criando Ephemeral Key para o cliente: ${customerId}...`);
      const ephemeralKey = await stripeClient.ephemeralKeys.create(
        { customer: customerId },
        { apiVersion: "2024-06-20" }
      );
      console.log("Ephemeral Key criada com sucesso.");

      // LOG 6: Buscando preço no Stripe
      console.log(`Buscando dados do preço no Stripe para o priceId: ${priceId}...`);
      const price = await stripeClient.prices.retrieve(priceId);
      if (!price || !price.unit_amount) {
          console.error(`ERRO: Preço com ID ${priceId} não encontrado no Stripe.`);
          throw new functions.https.HttpsError("not-found", "Preço não encontrado no Stripe.");
      }
      console.log(`Preço encontrado. Valor: ${price.unit_amount}`);

      // LOG 7: Criando Payment Intent
      console.log("Criando Payment Intent...");
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
        console.error("ERRO CRÍTICO: Payment Intent criado, mas client_secret está vazio.");
        throw new functions.https.HttpsError("internal", "Falha ao obter o client_secret do Payment Intent.");
      }
      
      // LOG 8: Sucesso! Retornando dados para o app.
      console.log("Payment Intent criado com sucesso. Retornando dados para o app Flutter.");
      return {
        paymentIntent: paymentIntent.client_secret,
        ephemeralKey: ephemeralKey.secret,
        customer: customerId,
        publishableKey: functions.config().stripe.publishable_key,
      };

    } catch (error: any) {
      console.error("ERRO DENTRO DO BLOCO TRY/CATCH:", error.message);
      throw new functions.https.HttpsError("internal", `Falha ao processar pagamento: ${error.message}`);
    }
  });


// =================== FUNÇÃO 3: WEBHOOK DO STRIPE ===================
// (Esta função já estava correta e não foi alterada)
export const stripeWebhook = functions
    .region("southamerica-east1")
    .https.onRequest(async (req, res) => {
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