// /functions/src/index.ts

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { onUserCreated, AuthEvent } from "firebase-functions/v2/auth";
import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions";
import * as admin from "firebase-admin";
import Stripe from "stripe";

admin.initializeApp();
const db = admin.firestore();

const stripeSecret = defineSecret("STRIPE_SECRET_KEY");

export const onusercreate = onUserCreated(
  { region: "southamerica-east1", secrets: [stripeSecret] },
  async (event: AuthEvent) => {
    const user = event.data;
    logger.info(`Novo usuário criado: ${user.email}, UID: ${user.uid}`);
    try {
      const stripeInstance = new Stripe(stripeSecret.value(), { apiVersion: "2024-04-10" });
      const customer = await stripeInstance.customers.create({
        email: user.email, name: user.displayName, metadata: { firebaseUID: user.uid },
      });
      logger.info(`Cliente Stripe criado para ${user.email} com ID ${customer.id}`);
      const trialEndDate = new Date();
      trialEndDate.setDate(trialEndDate.getDate() + 7);
      const customerDocRef = db.collection("clientes").doc(user.uid);
      await customerDocRef.set({
        email: user.email, stripeCustomerId: customer.id, statusAssinatura: "trial",
        features: { exportacao: false, analise: false },
        limites: { smartphone: 1, desktop: 0 },
        trial: {
          ativo: true, dataInicio: admin.firestore.FieldValue.serverTimestamp(),
          dataFim: admin.firestore.Timestamp.fromDate(trialEndDate),
        },
      });
      logger.info(`Documento de licença e trial criado para ${user.uid}`);
    } catch (error) {
      logger.error(`Erro ao configurar o novo usuário ${user.uid}:`, error);
    }
  }
);

export const createcheckoutsession = onCall<{ priceId: string }>(
  { region: "southamerica-east1", secrets: [stripeSecret] },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Você precisa estar logado.");
    }
    const stripeInstance = new Stripe(stripeSecret.value(), {
      apiVersion: "2024-04-10",
    });
    const uid = request.auth.uid;
    const priceId = request.data.priceId;
    try {
      const userDoc = await db.collection("clientes").doc(uid).get();
      if (!userDoc.exists) {
        throw new HttpsError("not-found", "Os dados da sua conta não foram encontrados.");
      }
      const customerId = userDoc.data()?.stripeCustomerId;
      if (!customerId) {
        throw new HttpsError("internal", "Sua conta de pagamento não está configurada.");
      }
      const session = await stripeInstance.checkout.sessions.create({
        payment_method_types: ["card"],
        mode: "subscription",
        customer: customerId,
        line_items: [{ price: priceId, quantity: 1 }],
        success_url: "https://geoforest.com.br/sucesso?session_id={CHECKOUT_SESSION_ID}",
        cancel_url: "https://geoforest.com.br/cancelamento",
        allow_promotion_codes: true,
      });
      if (!session.url) {
        throw new HttpsError("internal", "Não foi possível obter a URL de pagamento.");
      }
      return { url: session.url };
    } catch (error) {
      logger.error(`Erro ao criar a sessão de checkout para ${uid}:`, error);
      if (error instanceof HttpsError) {
        throw error;
      }
      throw new HttpsError("internal", "Não foi possível iniciar o pagamento.");
    }
  }
);