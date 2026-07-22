import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { FieldValue, Timestamp } from '@google-cloud/firestore';
import { createHash, randomBytes } from 'crypto';

admin.initializeApp();

type AccessRole = 'admin' | 'global_admin' | 'region_admin' | 'branch_admin' | 'member';
type MembershipStatus = 'unassigned' | 'active' | 'pending' | 'requested' | 'revoked';

type AdminScope = {
  uid: string;
  accessRole: AccessRole;
  orgId: string;
  regionId: string;
  branchId: string;
};

const accessRoles: AccessRole[] = [
  'admin',
  'global_admin',
  'region_admin',
  'branch_admin',
  'member',
];

const membershipStatuses: MembershipStatus[] = [
  'unassigned',
  'active',
  'pending',
  'requested',
  'revoked',
];

const inviteAlphabet = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
const inviteLength = 16;
const defaultInviteDurationDays = 90;
const defaultInviteMaxUses = 250;

async function assertGlobalAdmin(
  context: functions.https.CallableContext
): Promise<string> {
  const caller = await loadAdminScope(context);
  if (!isGlobalAdmin(caller.accessRole)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only global administrators can perform this action.'
    );
  }

  return caller.uid;
}

async function loadAdminScope(
  context: functions.https.CallableContext
): Promise<AdminScope> {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'You must be logged in to perform this action.'
    );
  }

  const callerUid = context.auth.uid;
  const callerDoc = await admin
    .firestore()
    .collection('users')
    .doc(callerUid)
    .get();
  const callerData = callerDoc.data();
  const accessRole = normalizedAccessRole(
    callerData?.accessRole || callerData?.role,
    'member'
  );
  const membershipStatus = normalizedMembershipStatus(
    callerData?.membershipStatus,
    callerData?.isApproved === true ? 'active' : 'pending'
  );

  if (
    !callerDoc.exists ||
    callerData?.isApproved !== true ||
    !['active', 'approved'].includes(membershipStatus) ||
    !['admin', 'global_admin', 'region_admin', 'branch_admin'].includes(accessRole)
  ) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only approved administrators can perform this action.'
    );
  }

  return {
    uid: callerUid,
    accessRole,
    orgId: String(callerData?.orgId || 'daniel-branch-church'),
    regionId: String(callerData?.regionId || ''),
    branchId: String(callerData?.branchId || ''),
  };
}

function normalizedAccessRole(value: unknown, fallback: AccessRole): AccessRole {
  if (typeof value === 'string' && accessRoles.includes(value as AccessRole)) {
    return value as AccessRole;
  }
  return fallback;
}

function normalizedMembershipStatus(
  value: unknown,
  fallback: MembershipStatus
): MembershipStatus {
  if (
    typeof value === 'string' &&
    membershipStatuses.includes(value as MembershipStatus)
  ) {
    return value as MembershipStatus;
  }
  return fallback;
}

function legacyRoleFor(accessRole: AccessRole): AccessRole {
  return accessRole === 'global_admin' ? 'admin' : accessRole;
}

function isGlobalAdmin(accessRole: AccessRole): boolean {
  return accessRole === 'admin' || accessRole === 'global_admin';
}

function targetCurrentRole(userData: FirebaseFirestore.DocumentData): AccessRole {
  return normalizedAccessRole(userData.accessRole || userData.role, 'member');
}

function assertCanSetUserAccess(params: {
  caller: AdminScope;
  targetUid: string;
  targetData: FirebaseFirestore.DocumentData;
  branchId: string;
  branchData?: FirebaseFirestore.DocumentData;
  accessRole: AccessRole;
}): void {
  const {
    caller,
    targetUid,
    targetData,
    branchId,
    branchData,
    accessRole,
  } = params;

  if (isGlobalAdmin(caller.accessRole)) {
    return;
  }

  if (targetUid === caller.uid) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Scoped administrators cannot change their own access.'
    );
  }

  const currentRole = targetCurrentRole(targetData);
  if (['admin', 'global_admin', 'region_admin'].includes(currentRole)) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Scoped administrators cannot manage global or regional administrators.'
    );
  }

  if (!branchId || !branchData) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Scoped administrator updates must include a valid branch.'
    );
  }

  const branchRegionId = String(branchData.regionId || '');
  const currentRegionId = String(targetData.regionId || '');
  const currentBranchId = String(targetData.branchId || '');

  if (caller.accessRole === 'region_admin') {
    if (!caller.regionId || branchRegionId !== caller.regionId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Region administrators can only manage users inside their region.'
      );
    }

    if (currentRegionId && currentRegionId !== caller.regionId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Region administrators cannot move users from another region.'
      );
    }

    if (!['member', 'branch_admin'].includes(accessRole)) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Region administrators can only assign member or branch admin roles.'
      );
    }

    return;
  }

  if (caller.accessRole === 'branch_admin') {
    if (!caller.branchId || branchId !== caller.branchId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Branch administrators can only manage users inside their branch.'
      );
    }

    if (currentBranchId && currentBranchId !== caller.branchId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Branch administrators cannot move users from another branch.'
      );
    }

    if (currentRole !== 'member' || accessRole !== 'member') {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Branch administrators can only approve or revoke member access.'
      );
    }

    return;
  }

  throw new functions.https.HttpsError(
    'permission-denied',
    'Your administrator role cannot perform this action.'
  );
}

function membershipId(branchId: string, uid: string): string {
  return `${branchId}_${uid}`;
}

function localizedText(value: unknown, fallback: string): string {
  if (typeof value === 'string' && value.trim()) {
    return value.trim();
  }

  if (value && typeof value === 'object') {
    const map = value as Record<string, unknown>;
    for (const key of ['en', 'zh', 'ko']) {
      const localizedValue = map[key];
      if (typeof localizedValue === 'string' && localizedValue.trim()) {
        return localizedValue.trim();
      }
    }
  }

  return fallback;
}

function assertCanManageBranch(
  caller: AdminScope,
  branchId: string,
  branchData: FirebaseFirestore.DocumentData
): void {
  if (isGlobalAdmin(caller.accessRole)) {
    return;
  }

  if (caller.accessRole === 'region_admin') {
    if (caller.regionId && caller.regionId === String(branchData.regionId || '')) {
      return;
    }
    throw new functions.https.HttpsError(
      'permission-denied',
      'Region administrators can only manage invites inside their region.'
    );
  }

  if (caller.accessRole === 'branch_admin' && caller.branchId === branchId) {
    return;
  }

  throw new functions.https.HttpsError(
    'permission-denied',
    'Branch administrators can only manage invites for their own branch.'
  );
}

function generateInviteCode(): string {
  const bytes = randomBytes(inviteLength);
  const raw = Array.from(bytes, (byte) => inviteAlphabet[byte & 31]).join('');
  return raw.match(/.{1,4}/g)?.join('-') || raw;
}

function normalizeInviteCode(value: unknown): string {
  if (typeof value !== 'string') {
    return '';
  }

  const normalized = value.toUpperCase().replace(/[\s-]/g, '');
  if (
    normalized.length !== inviteLength ||
    !Array.from(normalized).every((character) => inviteAlphabet.includes(character))
  ) {
    return '';
  }
  return normalized;
}

function hashInviteCode(normalizedCode: string): string {
  return createHash('sha256').update(normalizedCode, 'utf8').digest('hex');
}

async function loadBranch(branchId: string): Promise<{
  ref: FirebaseFirestore.DocumentReference;
  data: FirebaseFirestore.DocumentData;
}> {
  const ref = admin.firestore().collection('branches').doc(branchId);
  const snapshot = await ref.get();
  if (!snapshot.exists) {
    throw new functions.https.HttpsError('not-found', `Branch ${branchId} does not exist.`);
  }
  const data = snapshot.data() || {};
  if (data.isActive === false) {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Invites cannot be managed for an inactive branch.'
    );
  }
  return { ref, data };
}

export const ping = functions.https.onCall(
  (_data: unknown, _context: functions.https.CallableContext) => {
    return { status: 'ok', timestamp: new Date().toISOString() };
  }
);

export const deleteUserAdmin = functions
  .region('us-central1')
  .https.onCall(
    async (
      data: { uidToDelete?: string },
      context: functions.https.CallableContext
    ) => {
      if (!context.auth) {
        throw new functions.https.HttpsError('unauthenticated', 'You must be logged in to perform this action.');
      }

      const callerUid = await assertGlobalAdmin(context);

      const { uidToDelete } = data;
      if (!uidToDelete || typeof uidToDelete !== 'string') {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'A valid user UID must be provided.'
        );
      }

      if (uidToDelete === callerUid) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'You cannot delete your own admin account through this method.'
        );
      }

      try {
        await admin.auth().deleteUser(uidToDelete);
        console.log(`Deleted auth user: ${uidToDelete}`);
      } catch (authErr: any) {
        if (authErr.code !== 'auth/user-not-found') {
          console.error('Auth deletion failed:', authErr);
          throw new functions.https.HttpsError(
            'internal',
            `Failed to delete auth account: ${authErr.message}`
          );
        }
        console.log(`Auth user ${uidToDelete} already gone, continuing.`);
      }

      try {
        await admin.firestore().collection('users').doc(uidToDelete).delete();
        console.log(`Deleted Firestore doc: ${uidToDelete}`);

        const memberships = await admin
          .firestore()
          .collection('branchMemberships')
          .where('userId', '==', uidToDelete)
          .get();
        const batch = admin.firestore().batch();
        memberships.docs.forEach((membershipDoc) => {
          batch.delete(membershipDoc.ref);
        });
        await batch.commit();
        console.log(`Deleted ${memberships.size} membership docs for: ${uidToDelete}`);
      } catch (fsErr: any) {
        console.error('Firestore deletion failed:', fsErr);
        throw new functions.https.HttpsError(
          'internal',
          `Failed to delete Firestore profile: ${fsErr.message}`
        );
      }

      return {
        success: true,
        message: `User ${uidToDelete} completely removed.`,
      };
    }
  );

export const setUserAccessAdmin = functions
  .region('us-central1')
  .https.onCall(
    async (
      data: {
        uid?: unknown;
        isApproved?: unknown;
        branchId?: unknown;
        accessRole?: unknown;
        membershipStatus?: unknown;
      },
      context: functions.https.CallableContext
    ) => {
      const caller = await loadAdminScope(context);

      const uid = typeof data.uid === 'string' ? data.uid.trim() : '';
      if (!uid) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'A valid user UID must be provided.'
        );
      }

      const db = admin.firestore();
      const userRef = db.collection('users').doc(uid);
      const userDoc = await userRef.get();
      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          `User profile ${uid} does not exist.`
        );
      }

      const userData = userDoc.data() || {};
      const currentAccessRole = normalizedAccessRole(
        userData.accessRole || userData.role,
        'member'
      );
      const accessRole = normalizedAccessRole(data.accessRole, currentAccessRole);
      const role = legacyRoleFor(accessRole);
      const isApproved =
        typeof data.isApproved === 'boolean' ? data.isApproved : userData.isApproved === true;
      const currentMembershipStatus = normalizedMembershipStatus(
        userData.membershipStatus,
        isApproved ? 'active' : 'pending'
      );
      const membershipStatus = normalizedMembershipStatus(
        data.membershipStatus,
        isApproved ? 'active' : currentMembershipStatus
      );

      if (
        uid === caller.uid &&
        (!isApproved || !['admin', 'global_admin'].includes(accessRole))
      ) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'You cannot revoke or demote your own global admin account.'
        );
      }

      const branchId =
        typeof data.branchId === 'string' && data.branchId.trim()
          ? data.branchId.trim()
          : typeof userData.branchId === 'string'
            ? userData.branchId
            : '';

      let branchData: FirebaseFirestore.DocumentData | undefined;
      if (branchId) {
        const branchDoc = await db.collection('branches').doc(branchId).get();
        if (!branchDoc.exists) {
          throw new functions.https.HttpsError(
            'not-found',
            `Branch ${branchId} does not exist.`
          );
        }
        branchData = branchDoc.data();
      }

      assertCanSetUserAccess({
        caller,
        targetUid: uid,
        targetData: userData,
        branchId,
        branchData,
        accessRole,
      });

      const now = FieldValue.serverTimestamp();
      const branchName = branchData
        ? localizedText(branchData.name, branchId)
        : localizedText(userData.branchName, branchId);
      const regionName = branchData
        ? localizedText(branchData.regionName, String(branchData.regionId || ''))
        : localizedText(userData.regionName, String(userData.regionId || ''));
      const orgId = String(branchData?.orgId || userData.orgId || 'daniel-branch-church');
      const regionId = String(branchData?.regionId || userData.regionId || '');
      const country = String(branchData?.country || userData.churchCountry || regionName);

      const userUpdate: Record<string, unknown> = {
        isApproved,
        approvedAt: isApproved ? now : null,
        approvedBy: isApproved ? caller.uid : null,
        role,
        accessRole,
        membershipStatus,
        orgId,
        regionId,
        regionName,
        branchId,
        branchName,
        churchCountry: country,
        churchName: branchName,
        updatedAt: now,
      };

      const batch = db.batch();
      batch.update(userRef, userUpdate);

      const oldBranchId = typeof userData.branchId === 'string' ? userData.branchId : '';
      if (oldBranchId && oldBranchId !== branchId) {
        batch.set(
          db.collection('branchMemberships').doc(membershipId(oldBranchId, uid)),
          {
            id: membershipId(oldBranchId, uid),
            userId: uid,
            orgId: userData.orgId || orgId,
            regionId: userData.regionId || regionId,
            branchId: oldBranchId,
            role: userData.role || 'member',
            accessRole: userData.accessRole || userData.role || 'member',
            status: 'revoked',
            updatedAt: now,
          },
          { merge: true }
        );
      }

      if (branchId) {
        batch.set(
          db.collection('branchMemberships').doc(membershipId(branchId, uid)),
          {
            id: membershipId(branchId, uid),
            userId: uid,
            orgId,
            regionId,
            branchId,
            role,
            accessRole,
            status: membershipStatus,
            createdAt: now,
            updatedAt: now,
            approvedAt: isApproved ? now : null,
            approvedBy: isApproved ? caller.uid : null,
          },
          { merge: true }
        );
      }

      await batch.commit();

      try {
        await admin.auth().setCustomUserClaims(uid, {
          accessRole,
          role,
          isApproved,
          membershipStatus,
          orgId,
          regionId,
          branchId,
        });
      } catch (authErr: any) {
        if (authErr.code !== 'auth/user-not-found') {
          throw authErr;
        }
      }

      return {
        success: true,
        uid,
        accessRole,
        role,
        isApproved,
        membershipStatus,
        orgId,
        regionId,
        branchId,
      };
    }
  );

export const createBranchInvite = functions
  .region('us-central1')
  .https.onCall(
    async (
      data: { branchId?: unknown; label?: unknown },
      context: functions.https.CallableContext
    ) => {
      const caller = await loadAdminScope(context);
      const branchId = typeof data.branchId === 'string' ? data.branchId.trim() : '';
      const label = typeof data.label === 'string' ? data.label.trim().slice(0, 80) : '';
      if (!branchId) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'A valid branch ID must be provided.'
        );
      }

      const branch = await loadBranch(branchId);
      assertCanManageBranch(caller, branchId, branch.data);

      const db = admin.firestore();
      const inviteRef = db.collection('branchInvites').doc();
      const code = generateInviteCode();
      const normalizedCode = normalizeInviteCode(code);
      const tokenHash = hashInviteCode(normalizedCode);
      const expiresAt = Timestamp.fromMillis(
        Date.now() + defaultInviteDurationDays * 24 * 60 * 60 * 1000
      );
      const activeInvitesQuery = db
        .collection('branchInvites')
        .where('branchId', '==', branchId)
        .where('status', '==', 'active');

      await db.runTransaction(async (transaction) => {
        const activeInvites = await transaction.get(activeInvitesQuery);
        const now = FieldValue.serverTimestamp();
        activeInvites.docs.forEach((activeInvite) => {
          transaction.update(activeInvite.ref, {
            status: 'revoked',
            revokedAt: now,
            revokedBy: caller.uid,
            revokeReason: 'rotated',
            updatedAt: now,
          });
        });

        transaction.create(inviteRef, {
          id: inviteRef.id,
          tokenHash,
          branchId,
          orgId: String(branch.data.orgId || caller.orgId || 'daniel-branch-church'),
          regionId: String(branch.data.regionId || ''),
          label,
          status: 'active',
          expiresAt,
          maxUses: defaultInviteMaxUses,
          useCount: 0,
          createdBy: caller.uid,
          createdAt: now,
          updatedAt: now,
        });
      });

      return {
        success: true,
        inviteId: inviteRef.id,
        code,
        branchId,
        branchName: localizedText(branch.data.name, branchId),
        expiresAt: expiresAt.toDate().toISOString(),
        maxUses: defaultInviteMaxUses,
      };
    }
  );

export const listBranchInvites = functions
  .region('us-central1')
  .https.onCall(
    async (
      data: { branchId?: unknown },
      context: functions.https.CallableContext
    ) => {
      const caller = await loadAdminScope(context);
      const branchId = typeof data.branchId === 'string' ? data.branchId.trim() : '';
      if (!branchId) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'A valid branch ID must be provided.'
        );
      }
      const branch = await loadBranch(branchId);
      assertCanManageBranch(caller, branchId, branch.data);

      const snapshot = await admin
        .firestore()
        .collection('branchInvites')
        .where('branchId', '==', branchId)
        .limit(100)
        .get();
      const invites = snapshot.docs
        .map((document) => {
          const invite = document.data();
          const timestampToISOString = (value: unknown): string | null => {
            if (value && typeof (value as FirebaseFirestore.Timestamp).toDate === 'function') {
              return (value as FirebaseFirestore.Timestamp).toDate().toISOString();
            }
            return null;
          };
          return {
            inviteId: document.id,
            label: typeof invite.label === 'string' ? invite.label : '',
            status: typeof invite.status === 'string' ? invite.status : 'revoked',
            expiresAt: timestampToISOString(invite.expiresAt),
            maxUses: Number(invite.maxUses || defaultInviteMaxUses),
            useCount: Number(invite.useCount || 0),
            createdAt: timestampToISOString(invite.createdAt),
          };
        })
        .sort((left, right) => (right.createdAt || '').localeCompare(left.createdAt || ''));

      return { success: true, branchId, invites };
    }
  );

export const revokeBranchInvite = functions
  .region('us-central1')
  .https.onCall(
    async (
      data: { inviteId?: unknown },
      context: functions.https.CallableContext
    ) => {
      const caller = await loadAdminScope(context);
      const inviteId = typeof data.inviteId === 'string' ? data.inviteId.trim() : '';
      if (!inviteId) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'A valid invite ID must be provided.'
        );
      }

      const db = admin.firestore();
      const inviteRef = db.collection('branchInvites').doc(inviteId);
      const invite = await inviteRef.get();
      if (!invite.exists) {
        throw new functions.https.HttpsError('not-found', 'Invite does not exist.');
      }
      const inviteData = invite.data() || {};
      const branchId = String(inviteData.branchId || '');
      const branch = await loadBranch(branchId);
      assertCanManageBranch(caller, branchId, branch.data);

      if (inviteData.status !== 'revoked') {
        await inviteRef.update({
          status: 'revoked',
          revokedAt: FieldValue.serverTimestamp(),
          revokedBy: caller.uid,
          revokeReason: 'manual',
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      return { success: true, inviteId, branchId, status: 'revoked' };
    }
  );

export const redeemBranchInvite = functions
  .region('us-central1')
  .https.onCall(
    async (
      data: { code?: unknown },
      context: functions.https.CallableContext
    ) => {
      if (!context.auth) {
        throw new functions.https.HttpsError(
          'unauthenticated',
          'You must be logged in to redeem a church invite.'
        );
      }
      if (context.auth.token.email_verified !== true) {
        throw new functions.https.HttpsError(
          'failed-precondition',
          'Verify your email before redeeming a church invite.',
          { reason: 'email-not-verified' }
        );
      }

      const normalizedCode = normalizeInviteCode(data.code);
      if (!normalizedCode) {
        throw new functions.https.HttpsError(
          'invalid-argument',
          'Enter a valid 16-character church invite code.',
          { reason: 'invalid-code' }
        );
      }

      const uid = context.auth.uid;
      const db = admin.firestore();
      const inviteQuery = db
        .collection('branchInvites')
        .where('tokenHash', '==', hashInviteCode(normalizedCode))
        .limit(1);
      const inviteQuerySnapshot = await inviteQuery.get();
      if (inviteQuerySnapshot.empty) {
        throw new functions.https.HttpsError(
          'not-found',
          'This church invite code is invalid.',
          { reason: 'invalid-code' }
        );
      }

      const inviteRef = inviteQuerySnapshot.docs[0].ref;
      const inviteId = inviteRef.id;
      const userRef = db.collection('users').doc(uid);
      const redemptionRef = db.collection('inviteRedemptions').doc(`${inviteId}_${uid}`);

      const result = await db.runTransaction(async (transaction) => {
        const [inviteSnapshot, userSnapshot, previousRedemption] = await Promise.all([
          transaction.get(inviteRef),
          transaction.get(userRef),
          transaction.get(redemptionRef),
        ]);

        if (previousRedemption.exists && previousRedemption.data()?.status === 'success') {
          const previous = previousRedemption.data() || {};
          const currentAccessRole = normalizedAccessRole(
            userSnapshot.data()?.accessRole || userSnapshot.data()?.role,
            'member'
          );
          return {
            branchId: String(previous.branchId || ''),
            branchName: String(previous.branchName || previous.branchId || ''),
            orgId: String(userSnapshot.data()?.orgId || 'daniel-branch-church'),
            regionId: String(userSnapshot.data()?.regionId || ''),
            accessRole: currentAccessRole,
            role: legacyRoleFor(currentAccessRole),
            isApproved: userSnapshot.data()?.isApproved === true,
            membershipStatus: normalizedMembershipStatus(
              userSnapshot.data()?.membershipStatus,
              userSnapshot.data()?.isApproved === true ? 'active' : 'pending'
            ),
            idempotent: true,
          };
        }
        if (!inviteSnapshot.exists) {
          throw new functions.https.HttpsError('not-found', 'This church invite no longer exists.');
        }
        if (!userSnapshot.exists) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Complete your account profile before joining a church.',
            { reason: 'profile-required' }
          );
        }

        const invite = inviteSnapshot.data() || {};
        const user = userSnapshot.data() || {};
        const currentRole = normalizedAccessRole(user.accessRole || user.role, 'member');
        if (currentRole !== 'member') {
          throw new functions.https.HttpsError(
            'permission-denied',
            'Administrator accounts cannot redeem member invite codes.'
          );
        }

        if (invite.status !== 'active') {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'This church invite has been revoked.',
            { reason: 'revoked' }
          );
        }
        const expiresAt = invite.expiresAt as FirebaseFirestore.Timestamp | undefined;
        if (!expiresAt || expiresAt.toMillis() <= Date.now()) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'This church invite has expired.',
            { reason: 'expired' }
          );
        }
        const useCount = Number(invite.useCount || 0);
        const maxUses = Number(invite.maxUses || defaultInviteMaxUses);
        if (useCount >= maxUses) {
          throw new functions.https.HttpsError(
            'resource-exhausted',
            'This church invite has reached its usage limit.',
            { reason: 'usage-limit' }
          );
        }

        const branchId = String(invite.branchId || '');
        const branchRef = db.collection('branches').doc(branchId);
        const branchSnapshot = await transaction.get(branchRef);
        if (!branchSnapshot.exists || branchSnapshot.data()?.isActive === false) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'This church is not currently accepting members.',
            { reason: 'inactive-branch' }
          );
        }
        const branch = branchSnapshot.data() || {};
        const branchName = localizedText(branch.name, branchId);
        const currentBranchId = String(user.branchId || '');
        const currentStatus = normalizedMembershipStatus(
          user.membershipStatus,
          user.isApproved === true ? 'active' : 'unassigned'
        );
        if (
          currentBranchId &&
          currentBranchId !== branchId &&
          ['active', 'pending', 'requested'].includes(currentStatus)
        ) {
          throw new functions.https.HttpsError(
            'failed-precondition',
            'Leave or resolve your current church membership before joining another church.',
            { reason: 'existing-membership' }
          );
        }

        const now = FieldValue.serverTimestamp();
        const orgId = String(branch.orgId || invite.orgId || 'daniel-branch-church');
        const regionId = String(branch.regionId || invite.regionId || '');
        const regionName = localizedText(branch.regionName, regionId);
        const country = String(branch.country || '');
        const newMembershipId = membershipId(branchId, uid);

        transaction.update(inviteRef, {
          useCount: FieldValue.increment(1),
          lastRedeemedAt: now,
          updatedAt: now,
        });
        transaction.set(
          db.collection('branchMemberships').doc(newMembershipId),
          {
            id: newMembershipId,
            userId: uid,
            orgId,
            regionId,
            branchId,
            role: 'member',
            accessRole: 'member',
            status: 'pending',
            createdAt: now,
            updatedAt: now,
            requestedAt: now,
            requestedViaInviteId: inviteId,
          },
          { merge: true }
        );
        transaction.update(userRef, {
          isApproved: false,
          approvedAt: null,
          approvedBy: null,
          role: 'member',
          accessRole: 'member',
          membershipStatus: 'pending',
          orgId,
          regionId,
          regionName,
          branchId,
          branchName,
          churchCountry: country,
          churchName: branchName,
          updatedAt: now,
        });
        transaction.create(redemptionRef, {
          id: redemptionRef.id,
          inviteId,
          userId: uid,
          branchId,
          branchName,
          status: 'success',
          redeemedAt: now,
        });

        return {
          branchId,
          branchName,
          orgId,
          regionId,
          accessRole: 'member' as AccessRole,
          role: 'member' as AccessRole,
          isApproved: false,
          membershipStatus: 'pending' as MembershipStatus,
          idempotent: false,
        };
      });

      try {
        await admin.auth().setCustomUserClaims(uid, {
          accessRole: result.accessRole,
          role: result.role,
          isApproved: result.isApproved,
          membershipStatus: result.membershipStatus,
          orgId: result.orgId,
          regionId: result.regionId,
          branchId: result.branchId,
        });
      } catch (authErr: any) {
        if (authErr.code !== 'auth/user-not-found') {
          throw authErr;
        }
      }

      return {
        success: true,
        inviteId,
        branchId: result.branchId,
        branchName: result.branchName,
        membershipStatus: result.membershipStatus,
        idempotent: result.idempotent,
      };
    }
  );
