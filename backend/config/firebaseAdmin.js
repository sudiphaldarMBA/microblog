
const {
  initializeApp,
  cert,
  getApps,
} = require("firebase-admin/app");

const { getAuth } = require("firebase-admin/auth");

const initializeFirebaseAdmin = () => {
  try {
    const encodedCredentials =
      process.env.FIREBASE_SERVICE_ACCOUNT_BASE64;

    if (!encodedCredentials) {
      throw new Error(
        "FIREBASE_SERVICE_ACCOUNT_BASE64 is missing from backend .env"
      );
    }

    // Decode Base64 credentials.
    const credentialsJson = Buffer.from(
      encodedCredentials,
      "base64"
    ).toString("utf8");

    const serviceAccount = JSON.parse(credentialsJson);

    // Validate service-account credentials.
    if (
      !serviceAccount.project_id ||
      !serviceAccount.client_email ||
      !serviceAccount.private_key
    ) {
      throw new Error(
        "Firebase service-account credentials are incomplete."
      );
    }

    // Reuse an existing Firebase app or initialize a new one.
    let firebaseApp;

    if (getApps().length === 0) {
      firebaseApp = initializeApp({
        credential: cert({
          ...serviceAccount,
          private_key: serviceAccount.private_key.replace(
            /\\n/g,
            "\n"
          ),
        }),
        projectId: serviceAccount.project_id,
      });
    } else {
      firebaseApp = getApps()[0];
    }

    console.log("✅ Firebase Admin initialized successfully");

    return {
      app: firebaseApp,
      auth: getAuth(firebaseApp),
    };
  } catch (error) {
    console.error(
      "❌ Firebase Admin initialization failed:",
      error.message
    );

    throw error;
  }
};

module.exports = initializeFirebaseAdmin();
