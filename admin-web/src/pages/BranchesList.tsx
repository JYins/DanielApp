import React, { useEffect, useMemo, useState } from 'react';
import {
  collection,
  deleteDoc,
  doc,
  getDocs,
  orderBy,
  query,
  serverTimestamp,
  setDoc
} from 'firebase/firestore';
import { Building2, CheckCircle, Edit, MapPinned, Plus, Save, Trash2, XCircle } from 'lucide-react';
import { db } from '../lib/firebase';

type LocalizedName = {
  zh?: string;
  en?: string;
  ko?: string;
};

type Region = {
  id: string;
  orgId?: string;
  code?: string;
  name?: LocalizedName;
  country?: string;
  isActive?: boolean;
  sortOrder?: number;
};

type Branch = {
  id: string;
  orgId?: string;
  regionId?: string;
  regionName?: LocalizedName;
  code?: string;
  name?: LocalizedName;
  country?: string;
  city?: string;
  timezone?: string;
  isActive?: boolean;
  sortOrder?: number;
};

const ORG_ID = 'daniel-branch-church';

const emptyRegion = {
  id: '',
  nameZh: '',
  nameEn: '',
  nameKo: '',
  country: '',
  isActive: true,
  sortOrder: 10
};

const emptyBranch = {
  id: '',
  regionId: '',
  nameZh: '',
  nameEn: '',
  nameKo: '',
  country: '',
  city: '',
  timezone: 'America/Toronto',
  isActive: true,
  sortOrder: 10
};

function slugify(value: string, fallback: string) {
  const slug = value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
  return slug || fallback;
}

function localized(zh: string, en: string, ko: string) {
  return {
    zh: zh.trim() || en.trim() || ko.trim(),
    en: en.trim() || zh.trim() || ko.trim(),
    ko: ko.trim() || zh.trim() || en.trim()
  };
}

function displayName(name?: LocalizedName) {
  return name?.en || name?.zh || name?.ko || '—';
}

export default function BranchesList() {
  const [regions, setRegions] = useState<Region[]>([]);
  const [branches, setBranches] = useState<Branch[]>([]);
  const [loading, setLoading] = useState(true);
  const [regionForm, setRegionForm] = useState(emptyRegion);
  const [branchForm, setBranchForm] = useState(emptyBranch);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchBranchSystem();
  }, []);

  const regionById = useMemo(() => {
    return Object.fromEntries(regions.map(region => [region.id, region]));
  }, [regions]);

  const fetchBranchSystem = async () => {
    setLoading(true);
    try {
      const [regionsSnap, branchesSnap] = await Promise.all([
        getDocs(query(collection(db, 'regions'), orderBy('sortOrder', 'asc'))),
        getDocs(query(collection(db, 'branches'), orderBy('sortOrder', 'asc')))
      ]);

      setRegions(regionsSnap.docs.map(d => ({ id: d.id, ...d.data() } as Region)));
      setBranches(branchesSnap.docs.map(d => ({ id: d.id, ...d.data() } as Branch)));
    } catch (err) {
      console.error('Failed to fetch branch system', err);
      alert('Failed to load branch system.');
    } finally {
      setLoading(false);
    }
  };

  const saveRegion = async () => {
    const name = localized(regionForm.nameZh, regionForm.nameEn, regionForm.nameKo);
    const id = regionForm.id.trim() || slugify(name.en || name.zh || regionForm.country, 'new-region');
    const existing = regions.some(region => region.id === id);

    setSaving(true);
    try {
      await setDoc(doc(db, 'regions', id), {
        id,
        orgId: ORG_ID,
        code: id,
        name,
        country: regionForm.country.trim(),
        isActive: regionForm.isActive,
        sortOrder: Number(regionForm.sortOrder) || 10,
        ...(existing ? {} : { createdAt: serverTimestamp() }),
        updatedAt: serverTimestamp()
      }, { merge: true });
      setRegionForm(emptyRegion);
      await fetchBranchSystem();
    } catch (err) {
      console.error('Failed to save region', err);
      alert('Failed to save region.');
    } finally {
      setSaving(false);
    }
  };

  const saveBranch = async () => {
    const selectedRegion = regionById[branchForm.regionId];
    const name = localized(branchForm.nameZh, branchForm.nameEn, branchForm.nameKo);
    const id = branchForm.id.trim() || `${branchForm.regionId}-${slugify(name.en || name.zh || branchForm.city, 'new-branch')}`;
    const existing = branches.some(branch => branch.id === id);
    const regionName = selectedRegion?.name || localized(branchForm.regionId, branchForm.regionId, branchForm.regionId);

    setSaving(true);
    try {
      await setDoc(doc(db, 'branches', id), {
        id,
        orgId: ORG_ID,
        regionId: branchForm.regionId,
        regionName,
        code: id,
        name,
        country: branchForm.country.trim(),
        city: branchForm.city.trim(),
        timezone: branchForm.timezone.trim() || 'America/Toronto',
        isActive: branchForm.isActive,
        sortOrder: Number(branchForm.sortOrder) || 10,
        ...(existing ? {} : { createdAt: serverTimestamp() }),
        updatedAt: serverTimestamp()
      }, { merge: true });
      setBranchForm(emptyBranch);
      await fetchBranchSystem();
    } catch (err) {
      console.error('Failed to save branch', err);
      alert('Failed to save branch.');
    } finally {
      setSaving(false);
    }
  };

  const editRegion = (region: Region) => {
    setRegionForm({
      id: region.id,
      nameZh: region.name?.zh || '',
      nameEn: region.name?.en || '',
      nameKo: region.name?.ko || '',
      country: region.country || '',
      isActive: region.isActive !== false,
      sortOrder: region.sortOrder || 10
    });
  };

  const editBranch = (branch: Branch) => {
    setBranchForm({
      id: branch.id,
      regionId: branch.regionId || '',
      nameZh: branch.name?.zh || '',
      nameEn: branch.name?.en || '',
      nameKo: branch.name?.ko || '',
      country: branch.country || '',
      city: branch.city || '',
      timezone: branch.timezone || 'America/Toronto',
      isActive: branch.isActive !== false,
      sortOrder: branch.sortOrder || 10
    });
  };

  const removeRegion = async (regionId: string) => {
    if (!window.confirm(`Delete region "${regionId}"? Branches using this region will not be deleted automatically.`)) return;
    await deleteDoc(doc(db, 'regions', regionId));
    await fetchBranchSystem();
  };

  const removeBranch = async (branchId: string) => {
    if (!window.confirm(`Delete branch "${branchId}"? User assignments and memberships should be reviewed first.`)) return;
    await deleteDoc(doc(db, 'branches', branchId));
    await fetchBranchSystem();
  };

  if (loading) return <div className="p-8">Loading branches...</div>;

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-gray-900">Branch System</h1>
          <p className="text-sm text-gray-500">Manage regions and local branches backed by Firebase.</p>
        </div>
        <button
          onClick={fetchBranchSystem}
          className="inline-flex items-center rounded-md bg-amber-600 px-3 py-2 text-sm font-medium text-white hover:bg-amber-700"
        >
          Refresh
        </button>
      </div>

      <section className="bg-white shadow rounded-lg">
        <div className="border-b border-gray-200 px-6 py-4">
          <h2 className="flex items-center text-lg font-semibold text-gray-900">
            <MapPinned className="mr-2 h-5 w-5 text-amber-600" /> Regions
          </h2>
        </div>
        <div className="grid gap-4 p-6 md:grid-cols-2 lg:grid-cols-4">
          <input className="rounded-md border-gray-300 text-sm shadow-sm" placeholder="Region ID" value={regionForm.id} onChange={e => setRegionForm({ ...regionForm, id: e.target.value })} />
          <input className="rounded-md border-gray-300 text-sm shadow-sm" placeholder="Name zh" value={regionForm.nameZh} onChange={e => setRegionForm({ ...regionForm, nameZh: e.target.value })} />
          <input className="rounded-md border-gray-300 text-sm shadow-sm" placeholder="Name en" value={regionForm.nameEn} onChange={e => setRegionForm({ ...regionForm, nameEn: e.target.value })} />
          <input className="rounded-md border-gray-300 text-sm shadow-sm" placeholder="Name ko" value={regionForm.nameKo} onChange={e => setRegionForm({ ...regionForm, nameKo: e.target.value })} />
          <input className="rounded-md border-gray-300 text-sm shadow-sm" placeholder="Country code" value={regionForm.country} onChange={e => setRegionForm({ ...regionForm, country: e.target.value })} />
          <input className="rounded-md border-gray-300 text-sm shadow-sm" type="number" placeholder="Sort order" value={regionForm.sortOrder} onChange={e => setRegionForm({ ...regionForm, sortOrder: Number(e.target.value) })} />
          <label className="flex items-center text-sm text-gray-700">
            <input className="mr-2 rounded border-gray-300 text-amber-600" type="checkbox" checked={regionForm.isActive} onChange={e => setRegionForm({ ...regionForm, isActive: e.target.checked })} />
            Active
          </label>
          <button
            onClick={saveRegion}
            disabled={saving}
            className="inline-flex items-center justify-center rounded-md bg-green-600 px-3 py-2 text-sm font-medium text-white hover:bg-green-700 disabled:opacity-50"
          >
            <Save className="mr-2 h-4 w-4" /> Save Region
          </button>
        </div>
        <div className="divide-y divide-gray-200">
          {regions.map(region => (
            <div key={region.id} className="flex items-center justify-between px-6 py-3">
              <div>
                <div className="font-medium text-gray-900">{displayName(region.name)}</div>
                <div className="text-xs text-gray-500">{region.id} · {region.country || '—'} · sort {region.sortOrder || 0}</div>
              </div>
              <div className="flex items-center gap-3">
                {region.isActive !== false ? <CheckCircle className="h-4 w-4 text-green-600" /> : <XCircle className="h-4 w-4 text-gray-400" />}
                <button className="text-amber-700 hover:text-amber-900" onClick={() => editRegion(region)}><Edit className="h-4 w-4" /></button>
                <button className="text-red-600 hover:text-red-900" onClick={() => removeRegion(region.id)}><Trash2 className="h-4 w-4" /></button>
              </div>
            </div>
          ))}
        </div>
      </section>

      <section className="bg-white shadow rounded-lg">
        <div className="border-b border-gray-200 px-6 py-4">
          <h2 className="flex items-center text-lg font-semibold text-gray-900">
            <Building2 className="mr-2 h-5 w-5 text-amber-600" /> Branches
          </h2>
        </div>
        <div className="grid gap-4 p-6 md:grid-cols-2 lg:grid-cols-4">
          <input className="rounded-md border-gray-300 text-sm shadow-sm" placeholder="Branch ID" value={branchForm.id} onChange={e => setBranchForm({ ...branchForm, id: e.target.value })} />
          <select className="rounded-md border-gray-300 text-sm shadow-sm" value={branchForm.regionId} onChange={e => setBranchForm({ ...branchForm, regionId: e.target.value })}>
            <option value="">Select region</option>
            {regions.map(region => <option key={region.id} value={region.id}>{displayName(region.name)}</option>)}
          </select>
          <input className="rounded-md border-gray-300 text-sm shadow-sm" placeholder="Name zh" value={branchForm.nameZh} onChange={e => setBranchForm({ ...branchForm, nameZh: e.target.value })} />
          <input className="rounded-md border-gray-300 text-sm shadow-sm" placeholder="Name en" value={branchForm.nameEn} onChange={e => setBranchForm({ ...branchForm, nameEn: e.target.value })} />
          <input className="rounded-md border-gray-300 text-sm shadow-sm" placeholder="Name ko" value={branchForm.nameKo} onChange={e => setBranchForm({ ...branchForm, nameKo: e.target.value })} />
          <input className="rounded-md border-gray-300 text-sm shadow-sm" placeholder="Country code" value={branchForm.country} onChange={e => setBranchForm({ ...branchForm, country: e.target.value })} />
          <input className="rounded-md border-gray-300 text-sm shadow-sm" placeholder="City" value={branchForm.city} onChange={e => setBranchForm({ ...branchForm, city: e.target.value })} />
          <input className="rounded-md border-gray-300 text-sm shadow-sm" placeholder="Timezone" value={branchForm.timezone} onChange={e => setBranchForm({ ...branchForm, timezone: e.target.value })} />
          <input className="rounded-md border-gray-300 text-sm shadow-sm" type="number" placeholder="Sort order" value={branchForm.sortOrder} onChange={e => setBranchForm({ ...branchForm, sortOrder: Number(e.target.value) })} />
          <label className="flex items-center text-sm text-gray-700">
            <input className="mr-2 rounded border-gray-300 text-amber-600" type="checkbox" checked={branchForm.isActive} onChange={e => setBranchForm({ ...branchForm, isActive: e.target.checked })} />
            Active
          </label>
          <button
            onClick={saveBranch}
            disabled={saving || !branchForm.regionId}
            className="inline-flex items-center justify-center rounded-md bg-green-600 px-3 py-2 text-sm font-medium text-white hover:bg-green-700 disabled:opacity-50"
          >
            <Plus className="mr-2 h-4 w-4" /> Save Branch
          </button>
        </div>
        <div className="divide-y divide-gray-200">
          {branches.map(branch => (
            <div key={branch.id} className="flex items-center justify-between px-6 py-3">
              <div>
                <div className="font-medium text-gray-900">{displayName(branch.name)}</div>
                <div className="text-xs text-gray-500">{branch.id} · {displayName(regionById[branch.regionId || '']?.name)} · {branch.city || '—'} · sort {branch.sortOrder || 0}</div>
              </div>
              <div className="flex items-center gap-3">
                {branch.isActive !== false ? <CheckCircle className="h-4 w-4 text-green-600" /> : <XCircle className="h-4 w-4 text-gray-400" />}
                <button className="text-amber-700 hover:text-amber-900" onClick={() => editBranch(branch)}><Edit className="h-4 w-4" /></button>
                <button className="text-red-600 hover:text-red-900" onClick={() => removeBranch(branch.id)}><Trash2 className="h-4 w-4" /></button>
              </div>
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
