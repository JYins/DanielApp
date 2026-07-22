import React, { useEffect, useMemo, useState } from 'react';
import { collection, getDocs, orderBy, query, where } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { CheckCircle, RefreshCw, Shield, UserMinus } from 'lucide-react';
import { useAuthContext } from '../components/AuthProvider';
import { db, functions } from '../lib/firebase';

type Member = {
  id: string;
  name?: string;
  displayName?: string;
  email?: string;
  branchId?: string;
  branchName?: string;
  churchName?: string;
  regionId?: string;
  accessRole?: string;
  role?: string;
  membershipStatus?: 'unassigned' | 'pending' | 'active' | 'revoked';
  isApproved?: boolean;
};

type Branch = {
  id: string;
  regionId?: string;
  name?: { en?: string; zh?: string; ko?: string };
};

function roleOf(member: Member) {
  return member.accessRole || member.role || 'member';
}

function statusOf(member: Member) {
  if (member.membershipStatus) return member.membershipStatus;
  if (!member.branchId) return 'unassigned';
  return member.isApproved ? 'active' : 'pending';
}

function nameOf(member: Member) {
  return member.name || member.displayName || member.email || 'Member';
}

function branchLabel(branch: Branch) {
  return branch.name?.en || branch.name?.zh || branch.name?.ko || branch.id;
}

const statusStyles: Record<string, string> = {
  active: 'bg-green-100 text-green-800',
  pending: 'bg-amber-100 text-amber-800',
  revoked: 'bg-red-100 text-red-800',
  unassigned: 'bg-gray-100 text-gray-700'
};

export default function UsersList() {
  const { adminProfile } = useAuthContext();
  const accessRole = adminProfile?.accessRole || adminProfile?.role;
  const isGlobalAdmin = ['admin', 'global_admin'].includes(accessRole);
  const isRegionAdmin = accessRole === 'region_admin';
  const isBranchAdmin = accessRole === 'branch_admin';
  const [members, setMembers] = useState<Member[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [filter, setFilter] = useState('pending');
  const [loading, setLoading] = useState(true);
  const [busyId, setBusyId] = useState('');
  const [error, setError] = useState('');

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      let membersQuery = query(collection(db, 'users'));
      if (isRegionAdmin && adminProfile?.regionId) {
        membersQuery = query(collection(db, 'users'), where('regionId', '==', adminProfile.regionId));
      } else if (isBranchAdmin && adminProfile?.branchId) {
        membersQuery = query(collection(db, 'users'), where('branchId', '==', adminProfile.branchId));
      }
      const memberSnap = await getDocs(membersQuery);
      setMembers(memberSnap.docs.map(item => ({ id: item.id, ...item.data() } as Member)));

      if (isGlobalAdmin || isRegionAdmin) {
        let branchQuery = query(collection(db, 'branches'), orderBy('sortOrder', 'asc'));
        if (isRegionAdmin && adminProfile?.regionId) {
          branchQuery = query(collection(db, 'branches'), where('regionId', '==', adminProfile.regionId), orderBy('sortOrder', 'asc'));
        }
        const branchSnap = await getDocs(branchQuery);
        setBranches(branchSnap.docs.map(item => ({ id: item.id, ...item.data() } as Branch)));
      }
    } catch (loadError) {
      console.error(loadError);
      setError('Members could not be loaded for your admin scope.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { load(); }, [adminProfile?.id]);

  const canManage = (member: Member) => {
    const role = roleOf(member);
    if (isGlobalAdmin) return true;
    if (['admin', 'global_admin', 'region_admin'].includes(role)) return false;
    if (isRegionAdmin) return member.regionId === adminProfile?.regionId;
    return isBranchAdmin && role === 'member' && member.branchId === adminProfile?.branchId;
  };

  const updateAccess = async (member: Member, changes: { membershipStatus?: string; branchId?: string; accessRole?: string }) => {
    if (!canManage(member)) return;
    const membershipStatus = changes.membershipStatus || statusOf(member);
    const branchId = changes.branchId ?? member.branchId;
    const nextRole = changes.accessRole || roleOf(member);
    setBusyId(member.id);
    setError('');
    try {
      const callable = httpsCallable(functions, 'setUserAccessAdmin');
      await callable({
        uid: member.id,
        branchId: branchId || undefined,
        accessRole: nextRole,
        membershipStatus,
        isApproved: membershipStatus === 'active'
      });
      setMembers(current => current.map(item => item.id === member.id ? {
        ...item,
        branchId,
        accessRole: nextRole,
        role: nextRole === 'global_admin' ? 'admin' : nextRole,
        membershipStatus: membershipStatus as Member['membershipStatus'],
        isApproved: membershipStatus === 'active'
      } : item));
    } catch (updateError: any) {
      console.error(updateError);
      setError(updateError?.message || 'The server could not update this member. No client-side fallback was used.');
    } finally {
      setBusyId('');
    }
  };

  const visibleMembers = useMemo(() => members.filter(member => filter === 'all' || statusOf(member) === filter), [members, filter]);
  const counts = useMemo(() => ({
    pending: members.filter(member => statusOf(member) === 'pending').length,
    active: members.filter(member => statusOf(member) === 'active').length,
    revoked: members.filter(member => statusOf(member) === 'revoked').length,
    unassigned: members.filter(member => statusOf(member) === 'unassigned').length
  }), [members]);

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <p className="text-sm font-semibold uppercase tracking-[0.18em] text-amber-600">Church access</p>
          <h1 className="mt-1 text-2xl font-bold text-gray-900">Members</h1>
          <p className="mt-1 text-sm text-gray-500">Only identity, church, membership status and administrative access are shown.</p>
        </div>
        <button onClick={load} className="inline-flex items-center rounded-lg border border-gray-300 bg-white px-3 py-2 text-sm font-medium text-gray-700 hover:bg-gray-50"><RefreshCw className="mr-2 h-4 w-4" /> Refresh</button>
      </div>

      {error && <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">{error}</div>}

      <div className="grid grid-cols-2 gap-3 md:grid-cols-4">
        {(['pending', 'active', 'revoked', 'unassigned'] as const).map(status => (
          <button key={status} onClick={() => setFilter(filter === status ? 'all' : status)} className={`rounded-2xl border p-4 text-left shadow-sm transition ${filter === status ? 'border-amber-400 bg-amber-50' : 'border-gray-200 bg-white hover:border-amber-200'}`}>
            <div className="text-xs font-semibold uppercase tracking-wide text-gray-500">{status}</div>
            <div className="mt-1 text-2xl font-bold text-gray-900">{counts[status]}</div>
          </button>
        ))}
      </div>

      <div className="overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm">
        {loading ? <div className="p-8 text-center text-gray-500">Loading members…</div> : (
          <div className="overflow-x-auto">
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-[#fffaf0]">
                <tr>
                  <th className="px-5 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Member</th>
                  <th className="px-5 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Church</th>
                  <th className="px-5 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Status</th>
                  {isGlobalAdmin && <th className="px-5 py-3 text-left text-xs font-semibold uppercase tracking-wide text-gray-500">Access</th>}
                  <th className="px-5 py-3 text-right text-xs font-semibold uppercase tracking-wide text-gray-500">Action</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-100">
                {visibleMembers.map(member => {
                  const status = statusOf(member);
                  const manageable = canManage(member);
                  return (
                    <tr key={member.id}>
                      <td className="px-5 py-4">
                        <div className="font-medium text-gray-900">{nameOf(member)}</div>
                        <div className="text-sm text-gray-500">{member.email || '—'}</div>
                      </td>
                      <td className="px-5 py-4 text-sm text-gray-700">
                        {isGlobalAdmin || isRegionAdmin ? (
                          <select value={member.branchId || ''} disabled={!manageable || busyId === member.id} onChange={event => updateAccess(member, { branchId: event.target.value })} className="rounded-lg border-gray-300 text-sm focus:border-amber-500 focus:ring-amber-500">
                            <option value="">Unassigned</option>
                            {branches.map(branch => <option key={branch.id} value={branch.id}>{branchLabel(branch)}</option>)}
                          </select>
                        ) : (member.branchName || member.churchName || member.branchId || '—')}
                      </td>
                      <td className="px-5 py-4"><span className={`rounded-full px-2.5 py-1 text-xs font-semibold ${statusStyles[status]}`}>{status}</span></td>
                      {isGlobalAdmin && (
                        <td className="px-5 py-4">
                          <select value={roleOf(member)} disabled={busyId === member.id} onChange={event => updateAccess(member, { accessRole: event.target.value })} className="rounded-lg border-gray-300 text-sm focus:border-amber-500 focus:ring-amber-500">
                            <option value="member">Member</option>
                            <option value="branch_admin">Branch admin</option>
                            <option value="region_admin">Region admin</option>
                            <option value="global_admin">Global admin</option>
                          </select>
                        </td>
                      )}
                      <td className="px-5 py-4 text-right">
                        {manageable && status !== 'active' && member.branchId && <button disabled={busyId === member.id} onClick={() => updateAccess(member, { membershipStatus: 'active' })} className="inline-flex items-center text-sm font-semibold text-green-700 hover:text-green-900 disabled:opacity-50"><CheckCircle className="mr-1 h-4 w-4" /> Approve</button>}
                        {manageable && status === 'active' && <button disabled={busyId === member.id} onClick={() => updateAccess(member, { membershipStatus: 'revoked' })} className="inline-flex items-center text-sm font-semibold text-red-600 hover:text-red-800 disabled:opacity-50"><UserMinus className="mr-1 h-4 w-4" /> Revoke</button>}
                        {!manageable && <span className="inline-flex items-center text-xs text-gray-400"><Shield className="mr-1 h-3.5 w-3.5" /> Protected</span>}
                      </td>
                    </tr>
                  );
                })}
                {visibleMembers.length === 0 && <tr><td colSpan={isGlobalAdmin ? 5 : 4} className="px-5 py-10 text-center text-sm text-gray-500">No {filter === 'all' ? '' : filter} members.</td></tr>}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </div>
  );
}
