// /functions/src/index.ts

// Importações para a nova sintaxe v2 do Firebase Functions
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";

// Importações do Firebase Admin e do Stripe
import * as admin from "firebase-admin";
import Stripe from "stripe";

// Inicializa o Firebase Admin
admin.initializeApp();

// Carrega a chave secreta do Stripe que você configurou com o comando 'firebase functions:config:set'
// É mais seguro verificar se a chave existe.
const stripeSecret = process.env.STRIPE_SECRET;
if (!stripeSecret) {
  logger.error("A chave secreta do Stripe não foi configurada! Use 'firebase functions:config:set stripe.secret=sk_...'");
  throw new Error("A chave secreta do Stripe não está definida.");
}
const stripe = new Stripe(stripeSecret, { apiVersion: "2024-04-10" });

// =======================================================================
// FUNÇÃO COM A SINTAXE v2 CORRETA EM TYPESCRIPT
// =======================================================================
export const createCheckoutSession = onCall<{ priceId: string }>(
  // Opções da função, como a região
  { region: "southamerica-east1" },

  // Lógica da função
  async (request) => {
    // Verifica se o usuário está autenticado
    if (!request.auth) {
      logger.error("Tentativa de pagamento por usuário não autenticado.");
      throw new HttpsError("unauthenticated", "Você precisa estar logado para fazer um pagamento.");
    }

    const priceId = request.data.priceId;
    const uid = request.auth.uid;
    const email = request.auth.token.email;

    if (!priceId || !uid || !email) {
      logger.error("Faltando priceId, uid ou email na requisição.", { uid, email, priceId });
      throw new HttpsError("invalid-argument", "A requisição não contém as informações necessárias.");
    }

    try {
      // Busca pelo cliente Stripe no Firestore
      const userDoc = await admin.firestore().collection("users").doc(uid).get();
      let customerId = userDoc.data()?.stripeCustomerId;

      // Se não encontrar, cria um novo cliente no Stripe
      if (!customerId) {
        logger.info(`Criando novo cliente Stripe para o UID: ${uid}`);
        const customer = await stripe.customers.create({
          email: email,
          metadata: { firebaseUID: uid },
        });
        customerId = customer.id;
        // Salva o ID do novo cliente no Firestore para uso futuro
        await admin.firestore().collection("users").doc(uid).set({
          stripeCustomerId: customerId,
        }, { merge: true });
      }

      // Cria a sessão de Checkout do Stripe
      const session = await stripe.checkout.sessions.create({
        payment_method_types: ["card"],
        mode: "subscription",
        customer: customerId,
        line_items: [
          {
            price: priceId,
            quantity: 1,
          },
        ],
        // !! IMPORTANTE !! TROQUE ESTAS URLS PELAS SUAS URLS REAIS
        success_url: "https://geoforest.com.br/sucesso",
        cancel_url: "https://geoforest.com.br/cancelamento",
      });

      // Valida se a URL foi criada
      if (!session.url) {
        logger.error("A sessão de checkout do Stripe foi criada mas não possui uma URL.");
        throw new HttpsError("internal", "Não foi possível obter a URL de pagamento.");
      }

      // Retorna a URL para o aplicativo
      return { url: session.url };

    } catch (error) {
      logger.error("Erro ao criar a sessão de checkout do Stripe:", error);
      if (error instanceof HttpsError) {
        throw error; // Re-lança o erro se for um HttpsError
      }
      throw new HttpsError("internal", "Não foi possível iniciar o pagamento. Tente novamente.");
    }
  }
);