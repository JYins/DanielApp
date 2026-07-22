import React, { useEffect, useMemo, useState } from 'react';
import { collection, doc, getDoc, getDocs, orderBy, query, serverTimestamp, setDoc, where } from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { Check, Copy, ExternalLink, KeyRound, Link2, RefreshCw, Save, ShieldCheck, XCircle } from 'lucide-react';
import { useAuthContext } from '../components/AuthProvider';
import { db, functions } from '../lib/firebase';

type Branch = {
  id: string;
  name?: { en?: string; zh?: string; ko?: string };
  regionId?: string;
  isActive?: boolean;
};

type InviteMetadata = {
  inviteId: string;
  label?: string;
  status?: string;
  expiresAt?: unknown;
  maxUses?: number;
  useCount?: number;
  code?: string;
};

function branchName(branch?: Branch) {
  return branch?.name?.en || branch?.name?.zh || branch?.name?.ko || branch?.id || 'Church';
}

function dateLabel(value: any) {
  if (!value) return '—';
  if (typeof value === 'string') return new Date(value).toLocaleDateString();
  if (typeof value?.toDate === 'function') return value.toDate().toLocaleDateString();
  if (typeof value?.seconds === 'number') return new Date(value.seconds * 1000).toLocaleDateString();
  return '—';
}

function callableMessage(error: any, fallback: string) {
  return error?.message?.replace(/^FirebaseError:\s*/, '') || fallback;
}

export default function BranchAccess() {
  const { adminProfile } = useAuthContext();
  const accessRole = adminProfile?.accessRole || adminProfile?.role;
  const isGlobalAdmin = ['admin', 'global_admin'].includes(accessRole);
  const isRegionAdmin = accessRole === 'region_admin';
  const [branches, setBranches] = useState<Branch[]>([]);
  const [branchId, setBranchId] = useState(adminProfile?.branchId || '');
  const [label, setLabel] = useState('Canada pilot');
  const [invites, setInvites] = useState<InviteMetadata[]>([]);
  const [newCode, setNewCode] = useState('');
  const [copied, setCopied] = useState(false);
  const [groupNameZh, setGroupNameZh] = useState('');
  const [groupNameEn, setGroupNameEn] = useState('');
  const [groupNameKo, setGroupNameKo] = useState('');
  const [kakaoURL, setKakaoURL] = useState('');
  const [connectActive, setConnectActive] = useState(true);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [creating, setCreating] = useState(false);
  const [error, setError] = useState('');

  const selectedBranch = useMemo(() => branches.find(branch => branch.id === branchId), [branches, branchId]);

  useEffect(() => {
    const loadBranches = async () => {
      try {
        let branchQuery = query(collection(db, 'branches'), where('isActive', '==', true), orderBy('sortOrder', 'asc'));
        if (isRegionAdmin && adminProfile?.regionId) {
          branchQuery = query(
            collection(db, 'branches'),
            where('regionId', '==', adminProfile.regionId),
            where('isActive', '==', true),
            orderBy('sortOrder', 'asc')
          );
        }
        const snap = await getDocs(branchQuery);
        let loaded = snap.docs.map(item => ({ id: item.id, ...item.data() } as Branch));
        if (!isGlobalAdmin && !isRegionAdmin) {
          loaded = loaded.filter(branch => branch.id === adminProfile?.branchId);
        }
        setBranches(loaded);
        setBranchId(current => current || loaded[0]?.id || '');
      } catch (loadError) {
        console.error(loadError);
        setError('Churches could not be loaded. Check your admin scope and Firestore indexes.');
      } finally {
        setLoading(false);
      }
    };
    loadBranches();
  }, [adminProfile?.branchId, adminProfile?.regionId, isGlobalAdmin, isRegionAdmin]);

  useEffect(() => {
    if (!branchId) return;
    setNewCode('');
    setCopied(false);
    setError('');

    const loadBranchSettings = async () => {
      try {
        const connectSnap = await getDoc(doc(db, 'branchConnect', branchId));
        const connect = connectSnap.data();
        // The fallbacks keep older pilot documents editable, while every save
        // writes the exact BranchConnectInfo field names consumed by iOS.
        setGroupNameZh(connect?.groupNameZh || connect?.kakaoGroupName || '');
        setGroupNameEn(connect?.groupNameEn || connect?.kakaoGroupName || '');
        setGroupNameKo(connect?.groupNameKo || connect?.kakaoGroupName || '');
        setKakaoURL(connect?.kakaoURL || connect?.kakaoUrl || '');
        setConnectActive(connect?.isActive !== false);
      } catch (loadError) {
        console.error(loadError);
        setError('KakaoTalk settings could not be loaded for this church.');
      }

      // Metadata is returned through a callable so token hashes never become client-readable.
      try {
        const listInvites = httpsCallable<{ branchId: string }, { invites?: InviteMetadata[] }>(functions, 'listBranchInvites');
        const result = await listInvites({ branchId });
        setInvites(result.data?.invites || []);
      } catch (listError: any) {
        console.info('Invite metadata callable is not available yet.', listError?.code);
        setInvites([]);
      }
    };
    loadBranchSettings();
  }, [branchId]);

  const createInvite = async () => {
    if (!branchId) return;
    if (!window.confirm('Create a new church token? Any existing active token for this church will be revoked.')) return;
    setCreating(true);
    setError('');
    setNewCode('');
    try {
      const create = httpsCallable<{ branchId: string; label: string }, InviteMetadata>(functions, 'createBranchInvite');
      const result = await create({ branchId, label: label.trim() || 'Canada pilot' });
      const invite = result.data;
      setNewCode(invite.code || '');
      setInvites(current => [invite, ...current.map(item => ({ ...item, status: item.status === 'active' ? 'revoked' : item.status }))]);
    } catch (createError) {
      console.error(createError);
      setError(callableMessage(createError, 'Token creation failed. The server callable must be deployed or running in the emulator.'));
    } finally {
      setCreating(false);
    }
  };

  const revokeInvite = async (inviteId: string) => {
    if (!window.confirm('Revoke this token now? Members who already joined are not removed.')) return;
    setError('');
    try {
      const revoke = httpsCallable<{ inviteId: string }, { success?: boolean }>(functions, 'revokeBranchInvite');
      await revoke({ inviteId });
      setInvites(current => current.map(item => item.inviteId === inviteId ? { ...item, status: 'revoked' } : item));
      setNewCode('');
    } catch (revokeError) {
      console.error(revokeError);
      setError(callableMessage(revokeError, 'Token revocation failed.'));
    }
  };

  const copyCode = async () => {
    if (!newCode) return;
    await navigator.clipboard.writeText(newCode);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1800);
  };

  const saveConnect = async (event: React.FormEvent) => {
    event.preventDefault();
    if (!branchId) return;
    const trimmedUrl = kakaoURL.trim();
    if (trimmedUrl && !/^https:\/\//i.test(trimmedUrl)) {
      setError('KakaoTalk URL must begin with https://');
      return;
    }
    setSaving(true);
    setError('');
    try {
      await setDoc(doc(db, 'branchConnect', branchId), {
        branchId,
        groupNameZh: groupNameZh.trim(),
        groupNameEn: groupNameEn.trim(),
        groupNameKo: groupNameKo.trim(),
        kakaoURL: trimmedUrl,
        isActive: connectActive,
        updatedAt: serverTimestamp()
      }, { merge: true });
    } catch (saveError) {
      console.error(saveError);
      setError('KakaoTalk settings could not be saved.');
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <div className="p-8 text-gray-600">Loading church access…</div>;

  return (
    <div className="space-y-6">
      <div>
        <p className="text-sm font-semibold uppercase tracking-[0.18em] text-amber-600">Canada pilot</p>
        <h1 className="mt-1 text-2xl font-bold text-gray-900">Invite Token & KakaoTalk</h1>
        <p className="mt-2 max-w-3xl text-sm text-gray-600">Tokens identify a church and create a pending membership. They never grant admin access.</p>
      </div>

      {(isGlobalAdmin || isRegionAdmin) && (
        <label className="block max-w-md text-sm font-medium text-gray-700">
          Church
          <select value={branchId} onChange={event => setBranchId(event.target.value)} className="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-amber-500 focus:ring-amber-500">
            {branches.map(branch => <option key={branch.id} value={branch.id}>{branchName(branch)}</option>)}
          </select>
        </label>
      )}

      {error && <div className="rounded-xl border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-800">{error}</div>}

      {!branchId ? (
        <div className="rounded-2xl border border-amber-200 bg-amber-50 p-6 text-amber-900">Your admin profile is not assigned to a church.</div>
      ) : (
        <div className="grid gap-6 xl:grid-cols-2">
          <section className="rounded-2xl border border-amber-100 bg-[#fffdf8] p-6 shadow-sm">
            <div className="flex items-start justify-between gap-4">
              <div>
                <h2 className="flex items-center text-lg font-semibold text-gray-900"><KeyRound className="mr-2 h-5 w-5 text-amber-600" /> Church Token</h2>
                <p className="mt-1 text-sm text-gray-500">{branchName(selectedBranch)} · expires after 90 days · maximum 250 uses</p>
              </div>
              <ShieldCheck className="h-6 w-6 text-green-600" />
            </div>

            <div className="mt-5 flex gap-3">
              <input value={label} onChange={event => setLabel(event.target.value)} maxLength={80} placeholder="Token label" className="min-w-0 flex-1 rounded-lg border-gray-300 shadow-sm focus:border-amber-500 focus:ring-amber-500" />
              <button onClick={createInvite} disabled={creating} className="inline-flex items-center rounded-lg bg-amber-600 px-4 py-2 text-sm font-semibold text-white hover:bg-amber-700 disabled:opacity-50">
                <RefreshCw className={`mr-2 h-4 w-4 ${creating ? 'animate-spin' : ''}`} /> {creating ? 'Creating…' : 'Create / Rotate'}
              </button>
            </div>

            {newCode && (
              <div className="mt-5 rounded-xl border border-green-200 bg-green-50 p-4">
                <p className="text-xs font-semibold uppercase tracking-wide text-green-800">Copy now — shown only this time</p>
                <div className="mt-2 flex items-center gap-3">
                  <code className="flex-1 text-xl font-bold tracking-[0.12em] text-green-950">{newCode}</code>
                  <button onClick={copyCode} className="inline-flex items-center rounded-lg bg-white px-3 py-2 text-sm font-medium text-green-800 shadow-sm">
                    {copied ? <Check className="mr-1 h-4 w-4" /> : <Copy className="mr-1 h-4 w-4" />} {copied ? 'Copied' : 'Copy'}
                  </button>
                </div>
              </div>
            )}

            <div className="mt-5 space-y-3">
              {invites.map(invite => (
                <div key={invite.inviteId} className="flex items-center justify-between rounded-xl border border-gray-200 bg-white p-4">
                  <div>
                    <div className="flex items-center gap-2 text-sm font-semibold text-gray-900">
                      {invite.label || 'Church token'}
                      <span className={`rounded-full px-2 py-0.5 text-xs ${invite.status === 'active' ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-600'}`}>{invite.status || 'active'}</span>
                    </div>
                    <p className="mt-1 text-xs text-gray-500">Expires {dateLabel(invite.expiresAt)} · {invite.useCount || 0}/{invite.maxUses || 250} uses</p>
                  </div>
                  {invite.status === 'active' && <button onClick={() => revokeInvite(invite.inviteId)} className="inline-flex items-center text-sm font-medium text-red-600 hover:text-red-800"><XCircle className="mr-1 h-4 w-4" /> Revoke</button>}
                </div>
              ))}
              {invites.length === 0 && <p className="rounded-xl bg-gray-50 p-4 text-sm text-gray-500">No token metadata is available. Create a token or start the latest Functions emulator.</p>}
            </div>
          </section>

          <section className="rounded-2xl border border-amber-100 bg-[#fffdf8] p-6 shadow-sm">
            <h2 className="flex items-center text-lg font-semibold text-gray-900"><Link2 className="mr-2 h-5 w-5 text-amber-600" /> KakaoTalk Group</h2>
            <p className="mt-1 text-sm text-gray-500">This link is visible only to active members of {branchName(selectedBranch)}.</p>
            <form onSubmit={saveConnect} className="mt-5 space-y-4">
              <label className="block text-sm font-medium text-gray-700">Chinese group name
                <input value={groupNameZh} onChange={event => setGroupNameZh(event.target.value)} maxLength={100} placeholder="但以理教会群组" className="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-amber-500 focus:ring-amber-500" />
              </label>
              <label className="block text-sm font-medium text-gray-700">English group name
                <input value={groupNameEn} onChange={event => setGroupNameEn(event.target.value)} maxLength={100} placeholder="Daniel Church Community" className="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-amber-500 focus:ring-amber-500" />
              </label>
              <label className="block text-sm font-medium text-gray-700">Korean group name
                <input value={groupNameKo} onChange={event => setGroupNameKo(event.target.value)} maxLength={100} placeholder="다니엘 교회 공동체" className="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-amber-500 focus:ring-amber-500" />
              </label>
              <label className="block text-sm font-medium text-gray-700">KakaoTalk invitation URL
                <input type="url" value={kakaoURL} onChange={event => setKakaoURL(event.target.value)} placeholder="https://open.kakao.com/o/..." className="mt-1 block w-full rounded-lg border-gray-300 shadow-sm focus:border-amber-500 focus:ring-amber-500" />
              </label>
              <label className="flex items-center rounded-xl border border-gray-200 bg-white px-4 py-3 text-sm font-medium text-gray-700">
                <input type="checkbox" checked={connectActive} onChange={event => setConnectActive(event.target.checked)} className="mr-3 h-4 w-4 rounded border-gray-300 text-amber-600 focus:ring-amber-500" />
                Show KakaoTalk to active church members
              </label>
              <div className="flex items-center gap-3">
                <button type="submit" disabled={saving} className="inline-flex items-center rounded-lg bg-amber-600 px-4 py-2 text-sm font-semibold text-white hover:bg-amber-700 disabled:opacity-50"><Save className="mr-2 h-4 w-4" /> {saving ? 'Saving…' : 'Save'}</button>
                {kakaoURL && <a href={kakaoURL} target="_blank" rel="noreferrer" className="inline-flex items-center text-sm font-medium text-amber-700 hover:text-amber-900">Test link <ExternalLink className="ml-1 h-4 w-4" /></a>}
              </div>
            </form>
          </section>
        </div>
      )}
    </div>
  );
}
