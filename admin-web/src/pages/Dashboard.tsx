import React, { useEffect, useMemo, useState } from 'react';
import { collection, getDocs, query, where } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { ArrowRight, CheckCircle, KeyRound, Megaphone, Users } from 'lucide-react';
import { Link } from 'react-router-dom';
import { useAuthContext } from '../components/AuthProvider';
import { db, functions } from '../lib/firebase';

type Member = {
  id: string;
  name?: string;
  displayName?: string;
  email?: string;
  branchId?: string;
  branchName?: string;
  membershipStatus?: string;
  isApproved?: boolean;
  accessRole?: string;
  role?: string;
};

function memberStatus(member: Member) {
  if (member.membershipStatus) return member.membershipStatus;
  return member.isApproved ? 'active' : member.branchId ? 'pending' : 'unassigned';
}

export default function Dashboard() {
  const { adminProfile } = useAuthContext();
  const accessRole = adminProfile?.accessRole || adminProfile?.role;
  const isRegionAdmin = accessRole === 'region_admin';
  const isBranchAdmin = accessRole === 'branch_admin';
  const [members, setMembers] = useState<Member[]>([]);
  const [busyId, setBusyId] = useState('');
  const [error, setError] = useState('');

  useEffect(() => {
    const loadMembers = async () => {
      try {
        let membersQuery = query(collection(db, 'users'));
        if (isRegionAdmin && adminProfile?.regionId) membersQuery = query(collection(db, 'users'), where('regionId', '==', adminProfile.regionId));
        if (isBranchAdmin && adminProfile?.branchId) membersQuery = query(collection(db, 'users'), where('branchId', '==', adminProfile.branchId));
        const snap = await getDocs(membersQuery);
        setMembers(snap.docs.map(item => ({ id: item.id, ...item.data() } as Member)));
      } catch (loadError) {
        console.error(loadError);
        setError('Dashboard member data could not be loaded.');
      }
    };
    loadMembers();
  }, [adminProfile?.id]);

  const pending = useMemo(() => members.filter(member => memberStatus(member) === 'pending'), [members]);
  const activeCount = useMemo(() => members.filter(member => memberStatus(member) === 'active').length, [members]);

  const approve = async (member: Member) => {
    setBusyId(member.id);
    setError('');
    try {
      const callable = httpsCallable(functions, 'setUserAccessAdmin');
      await callable({
        uid: member.id,
        branchId: member.branchId,
        accessRole: member.accessRole || member.role || 'member',
        membershipStatus: 'active',
        isApproved: true
      });
      setMembers(current => current.map(item => item.id === member.id ? { ...item, membershipStatus: 'active', isApproved: true } : item));
    } catch (approveError: any) {
      console.error(approveError);
      setError(approveError?.message || 'Approval failed. No direct Firestore fallback was used.');
    } finally {
      setBusyId('');
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <p className="text-sm font-semibold uppercase tracking-[0.18em] text-amber-600">Canada pilot</p>
        <h1 className="mt-1 text-2xl font-bold text-gray-900">Church Dashboard</h1>
        <p className="mt-2 text-sm text-gray-500">Approve members, publish church updates and manage the private KakaoTalk link.</p>
      </div>

      {error && <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">{error}</div>}

      <div className="grid gap-4 md:grid-cols-3">
        <Link to="/users" className="rounded-2xl border border-amber-100 bg-[#fffdf8] p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md">
          <Users className="h-7 w-7 text-amber-600" />
          <div className="mt-4 text-3xl font-bold text-gray-900">{pending.length}</div>
          <div className="text-sm font-medium text-gray-600">Pending members</div>
        </Link>
        <Link to="/users" className="rounded-2xl border border-green-100 bg-green-50/50 p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md">
          <CheckCircle className="h-7 w-7 text-green-600" />
          <div className="mt-4 text-3xl font-bold text-gray-900">{activeCount}</div>
          <div className="text-sm font-medium text-gray-600">Active members</div>
        </Link>
        <Link to="/branch-access" className="rounded-2xl border border-orange-100 bg-orange-50/50 p-5 shadow-sm transition hover:-translate-y-0.5 hover:shadow-md">
          <KeyRound className="h-7 w-7 text-orange-600" />
          <div className="mt-4 text-lg font-bold text-gray-900">Invite & KakaoTalk</div>
          <div className="mt-1 flex items-center text-sm font-medium text-orange-700">Manage church access <ArrowRight className="ml-1 h-4 w-4" /></div>
        </Link>
      </div>

      <section className="overflow-hidden rounded-2xl border border-gray-200 bg-white shadow-sm">
        <div className="flex items-center justify-between border-b border-gray-200 px-5 py-4">
          <div>
            <h2 className="font-semibold text-gray-900">Pending approvals</h2>
            <p className="text-sm text-gray-500">Token redemption identifies the church but never auto-approves a member.</p>
          </div>
          <Link to="/users" className="text-sm font-semibold text-amber-700 hover:text-amber-900">View all</Link>
        </div>
        {pending.slice(0, 6).map(member => (
          <div key={member.id} className="flex flex-wrap items-center justify-between gap-3 border-b border-gray-100 px-5 py-4 last:border-0">
            <div>
              <div className="font-medium text-gray-900">{member.name || member.displayName || member.email || 'Member'}</div>
              <div className="text-sm text-gray-500">{member.email} · {member.branchName || member.branchId || 'Unassigned'}</div>
            </div>
            <button disabled={busyId === member.id || !member.branchId} onClick={() => approve(member)} className="inline-flex items-center rounded-lg bg-green-600 px-3 py-2 text-sm font-semibold text-white hover:bg-green-700 disabled:opacity-40"><CheckCircle className="mr-2 h-4 w-4" /> Approve</button>
          </div>
        ))}
        {pending.length === 0 && <div className="p-8 text-center text-sm text-gray-500">No members are waiting for approval.</div>}
      </section>

      <Link to="/newsletters" className="flex items-center justify-between rounded-2xl bg-amber-600 px-5 py-4 text-white shadow-sm hover:bg-amber-700">
        <span className="flex items-center font-semibold"><Megaphone className="mr-3 h-5 w-5" /> Publish an announcement or newsletter</span>
        <ArrowRight className="h-5 w-5" />
      </Link>
    </div>
  );
}
