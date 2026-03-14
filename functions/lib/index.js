"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteUserAccount = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
/**
 * Callable function to delete a user's Firebase Auth account and their Firestore profile.
 * Only accessible by an authenticated admin.
 */
exports.deleteUserAccount = functions.https.onCall(async (data, context) => {
    // 1. Verify Authentication & Authorization
    if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'You must be logged in to perform this action.');
    }
    const callerUid = context.auth.uid;
    // Verify the caller is actually an admin by checking their Firestore document
    const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
    const callerData = callerDoc.data();
    if (!callerDoc.exists || (callerData === null || callerData === void 0 ? void 0 : callerData.role) !== 'admin') {
        throw new functions.https.HttpsError('permission-denied', 'Only administrators can delete users.');
    }
    // 2. Extract input
    const { uidToDelete } = data;
    if (!uidToDelete || typeof uidToDelete !== 'string') {
        throw new functions.https.HttpsError('invalid-argument', 'A valid user UID must be provided.');
    }
    // Prevents an admin from accidentally deleting themselves via this specific route
    if (uidToDelete === callerUid) {
        throw new functions.https.HttpsError('invalid-argument', 'You cannot delete your own admin account through this method.');
    }
    try {
        // 3. Delete from Firebase Auth
        await admin.auth().deleteUser(uidToDelete);
        console.log(`Successfully deleted auth user: ${uidToDelete}`);
        // 4. Delete from Firestore
        await admin.firestore().collection('users').doc(uidToDelete).delete();
        console.log(`Successfully deleted firestore user doc: ${uidToDelete}`);
        return {
            success: true,
            message: `User ${uidToDelete} completely removed.`
        };
    }
    catch (error) {
        console.error('Error deleting user:', error);
        throw new functions.https.HttpsError('internal', 'Failed to completely delete user account.');
    }
});
//# sourceMappingURL=index.js.map