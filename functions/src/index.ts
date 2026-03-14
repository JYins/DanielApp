import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as logger from 'firebase-functions/logger';
import * as admin from 'firebase-admin';

admin.initializeApp();

/**
 * Simple ping function to verify connectivity.
 */
export const ping = onCall({ region: 'us-central1' }, (request) => {
  logger.info("Ping received", { data: request.data });
  return { status: "ok", timestamp: new Date().toISOString() };
});

/**
 * Callable function to delete a user's Firebase Auth account and their Firestore profile.
 * Only accessible by an authenticated admin.
 */
export const deleteUserAdmin = onCall({
  region: 'us-central1'
}, async (request) => {
  const { data, auth } = request;
  
  logger.info("Delete request received", { 
    uidToDelete: data?.uidToDelete,
    callerUid: auth?.uid 
  });

  // 1. Verify Authentication & Authorization
  if (!auth) {
    logger.warn("Unauthenticated attempt to delete user");
    throw new HttpsError(
      'unauthenticated',
      'You must be logged in to perform this action.'
    );
  }

  const callerUid = auth.uid;
  
  // Verify the caller is actually an admin by checking their Firestore document
  try {
    const callerDoc = await admin.firestore().collection('users').doc(callerUid).get();
    const callerData = callerDoc.data();
    
    if (!callerDoc.exists || callerData?.role !== 'admin') {
      logger.warn(`Unauthorized delete attempt by user: ${callerUid}`);
      throw new HttpsError(
        'permission-denied',
        'Only administrators can delete users.'
      );
    }
  } catch (err: any) {
    if (err instanceof HttpsError) throw err;
    logger.error("Error checking admin status", err);
    throw new HttpsError('internal', 'Internal security check failed.');
  }

  // 2. Extract input
  const { uidToDelete } = data;
  if (!uidToDelete || typeof uidToDelete !== 'string') {
    throw new HttpsError(
      'invalid-argument',
      'A valid user UID must be provided.'
    );
  }

  // Prevents an admin from accidentally deleting themselves
  if (uidToDelete === callerUid) {
     throw new HttpsError(
      'invalid-argument',
      'You cannot delete your own admin account through this method.'
    );
  }

  try {
    // 3. Delete from Firebase Auth
    await admin.auth().deleteUser(uidToDelete);
    logger.info(`Successfully deleted auth user: ${uidToDelete}`);

    // 4. Delete from Firestore
    await admin.firestore().collection('users').doc(uidToDelete).delete();
    logger.info(`Successfully deleted firestore user doc: ${uidToDelete}`);

    return { 
      success: true, 
      message: `User ${uidToDelete} completely removed.` 
    };
  } catch (error: any) {
    logger.error('Error deleting user:', error);
    
    // Auth errors usually have a code like auth/user-not-found
    if (error.code === 'auth/user-not-found') {
       // If auth user is gone, still try to delete firestore doc
       await admin.firestore().collection('users').doc(uidToDelete).delete();
       return { success: true, message: "Firestore doc removed (Auth user already gone)." };
    }

    throw new HttpsError(
      'internal',
      'Failed to completely delete user account.'
    );
  }
});
