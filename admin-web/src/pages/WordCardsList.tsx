import React, { useEffect, useState } from 'react';
import { collection, query, getDocs, addDoc, updateDoc, deleteDoc, doc, orderBy, Timestamp } from 'firebase/firestore';
import { ref, uploadBytes, getDownloadURL, deleteObject } from 'firebase/storage';
import { db, storage } from '../lib/firebase';
import { Plus, Edit2, Trash2, Image as ImageIcon, XCircle } from 'lucide-react';

// Helper: extract Storage path from a Firebase download URL
function getStoragePathFromUrl(url: string): string | null {
  try {
    const match = url.match(/\/o\/(.+?)(\?|$)/);
    if (match) return decodeURIComponent(match[1]);
  } catch {}
  return null;
}

export default function WordCardsList() {
  const [cards, setCards] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  
  // Form state
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState('grace');
  const [captionCn, setCaptionCn] = useState('');
  const [captionEn, setCaptionEn] = useState('');
  const [captionKr, setCaptionKr] = useState('');
  const [order, setOrder] = useState(0);
  const [published, setPublished] = useState(true);
  const [imageFiles, setImageFiles] = useState<FileList | null>(null);
  const [existingImages, setExistingImages] = useState<string[]>([]);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    fetchCards();
  }, []);

  const fetchCards = async () => {
    setLoading(true);
    try {
      const q = query(collection(db, 'wordCards'), orderBy('order', 'asc'));
      const snap = await getDocs(q);
      setCards(snap.docs.map(d => ({ id: d.id, ...d.data() })));
    } catch (err) {
      console.error(err);
    } finally {
      setLoading(false);
    }
  };

  const resetForm = () => {
    setTitle('');
    setCategory('grace');
    setCaptionCn('');
    setCaptionEn('');
    setCaptionKr('');
    setOrder(0);
    setPublished(true);
    setImageFiles(null);
    setExistingImages([]);
    setEditingId(null);
  };

  const openAddModal = () => {
    resetForm();
    setIsModalOpen(true);
  };

  const openEditModal = (card: any) => {
    setTitle(card.title || '');
    setCategory(card.category || 'grace');
    setCaptionCn(card.caption_cn || '');
    setCaptionEn(card.caption_en || '');
    setCaptionKr(card.caption_kr || '');
    setOrder(card.order || 0);
    setPublished(card.published ?? true);
    setExistingImages(card.image_urls || []);
    setEditingId(card.id);
    setIsModalOpen(true);
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Are you sure you want to delete this card?')) return;
    try {
      // Delete images from Storage
      const card = cards.find(c => c.id === id);
      for (const url of (card?.image_urls || [])) {
        const path = getStoragePathFromUrl(url);
        if (path) {
          try { await deleteObject(ref(storage, path)); } catch {}
        }
      }
      // Delete Firestore document
      await deleteDoc(doc(db, 'wordCards', id));
      setCards(prev => prev.filter(c => c.id !== id));
    } catch (err) {
      alert("Failed to delete card");
    }
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    try {
      let imageUrls = [...existingImages];

      // Upload new images if any
      if (imageFiles && imageFiles.length > 0) {
        for (let i = 0; i < imageFiles.length; i++) {
          const file = imageFiles[i];
          const storageRef = ref(storage, `wordCards/${Date.now()}_${file.name}`);
          const snapshot = await uploadBytes(storageRef, file);
          const url = await getDownloadURL(snapshot.ref);
          imageUrls.push(url);
        }
      }

      const cardData = {
        title,
        category,
        caption_cn: captionCn,
        caption_en: captionEn,
        caption_kr: captionKr,
        order: Number(order),
        published,
        image_urls: imageUrls,
        updatedAt: Timestamp.fromDate(new Date())
      };

      if (editingId) {
        await updateDoc(doc(db, 'wordCards', editingId), cardData);
      } else {
        await addDoc(collection(db, 'wordCards'), {
          ...cardData,
          createdAt: Timestamp.fromDate(new Date())
        });
      }

      setIsModalOpen(false);
      fetchCards();
    } catch (err) {
      console.error(err);
      alert("Failed to save card");
    } finally {
      setSaving(false);
    }
  };

  const removeExistingImage = (index: number) => {
    setExistingImages(prev => prev.filter((_, i) => i !== index));
  };

  if (loading) return <div className="p-8">Loading...</div>;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Word Cards</h1>
        <button
          onClick={openAddModal}
          className="flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-amber-600 hover:bg-amber-700"
        >
          <Plus className="h-4 w-4 mr-2" /> Add New
        </button>
      </div>

      <div className="bg-white shadow rounded-lg overflow-hidden">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Image</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Title & Category</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase">Status/Order</th>
              <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase">Actions</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {cards.map((card) => (
              <tr key={card.id}>
                <td className="px-6 py-4 whitespace-nowrap">
                  {card.image_urls && card.image_urls.length > 0 ? (
                    <img src={card.image_urls[0]} alt="" className="h-10 w-10 rounded object-cover" />
                  ) : (
                    <div className="h-10 w-10 rounded bg-gray-100 flex items-center justify-center">
                      <ImageIcon className="h-5 w-5 text-gray-400" />
                    </div>
                  )}
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <div className="text-sm font-medium text-gray-900">{card.title || 'Untitled'}</div>
                  <div className="text-sm text-gray-500">{card.category}</div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <span className={`px-2 inline-flex text-xs leading-5 font-semibold rounded-full ${card.published ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'}`}>
                    {card.published ? 'Published' : 'Draft'}
                  </span>
                  <div className="text-xs text-gray-500 mt-1">Order: {card.order}</div>
                </td>
                <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                  <button onClick={() => openEditModal(card)} className="text-amber-600 hover:text-amber-900 mr-4 inline-block">
                    <Edit2 className="h-4 w-4" />
                  </button>
                  <button onClick={() => handleDelete(card.id)} className="text-red-600 hover:text-red-900 inline-block">
                    <Trash2 className="h-4 w-4" />
                  </button>
                </td>
              </tr>
            ))}
            {cards.length === 0 && (
              <tr>
                <td colSpan={4} className="px-6 py-4 text-center text-sm text-gray-500">No word cards found.</td>
              </tr>
            )}
          </tbody>
        </table>
      </div>

      {/* Modal */}
      {isModalOpen && (
        <div className="fixed z-10 inset-0 overflow-y-auto" aria-labelledby="modal-title" role="dialog" aria-modal="true">
          <div className="flex items-end justify-center min-h-screen pt-4 px-4 pb-20 text-center sm:block sm:p-0">
            <div className="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity" aria-hidden="true" onClick={() => setIsModalOpen(false)}></div>
            <span className="hidden sm:inline-block sm:align-middle sm:h-screen" aria-hidden="true">&#8203;</span>
            <div className="inline-block align-bottom bg-white rounded-lg text-left overflow-hidden shadow-xl transform transition-all sm:my-8 sm:align-middle sm:max-w-lg w-full">
              <form onSubmit={handleSubmit}>
                <div className="bg-white px-4 pt-5 pb-4 sm:p-6 sm:pb-4 max-h-[70vh] overflow-y-auto">
                  <h3 className="text-lg leading-6 font-medium text-gray-900" id="modal-title">
                    {editingId ? 'Edit Word Card' : 'Add New Word Card'}
                  </h3>
                  <div className="mt-4 space-y-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Title (Internal reference)</label>
                      <input type="text" required value={title} onChange={e => setTitle(e.target.value)} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-amber-500 focus:border-amber-500 sm:text-sm" />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Category</label>
                      <select value={category} onChange={e => setCategory(e.target.value)} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-amber-500 focus:border-amber-500 sm:text-sm">
                        <option value="grace">Grace (恩典)</option>
                        <option value="encouragement">Encouragement (鼓励)</option>
                        <option value="wisdom">Wisdom (智慧)</option>
                      </select>
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Chinese Caption</label>
                      <textarea rows={3} value={captionCn} onChange={e => setCaptionCn(e.target.value)} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-amber-500 focus:border-amber-500 sm:text-sm" />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">English Caption</label>
                      <textarea rows={3} value={captionEn} onChange={e => setCaptionEn(e.target.value)} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-amber-500 focus:border-amber-500 sm:text-sm" />
                    </div>
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Korean Caption</label>
                      <textarea rows={3} value={captionKr} onChange={e => setCaptionKr(e.target.value)} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-amber-500 focus:border-amber-500 sm:text-sm" />
                    </div>
                    <div className="flex space-x-4">
                      <div className="flex-1">
                        <label className="block text-sm font-medium text-gray-700">Order</label>
                        <input type="number" value={order} onChange={e => setOrder(Number(e.target.value))} className="mt-1 block w-full border border-gray-300 rounded-md shadow-sm py-2 px-3 focus:outline-none focus:ring-amber-500 focus:border-amber-500 sm:text-sm" />
                      </div>
                      <div className="flex-1 flex items-center mt-5">
                        <input id="published" type="checkbox" checked={published} onChange={e => setPublished(e.target.checked)} className="h-4 w-4 text-amber-600 focus:ring-amber-500 border-gray-300 rounded" />
                        <label htmlFor="published" className="ml-2 block text-sm text-gray-900">
                          Published
                        </label>
                      </div>
                    </div>
                    
                    <div>
                      <label className="block text-sm font-medium text-gray-700">Images</label>
                      <div className="mt-2 flex items-center space-x-2">
                        {existingImages.map((url, i) => (
                          <div key={i} className="relative">
                            <img src={url} alt="" className="h-16 w-16 object-cover rounded" />
                            <button type="button" onClick={() => removeExistingImage(i)} className="absolute -top-2 -right-2 bg-red-500 text-white rounded-full p-1 shadow-sm">
                              <XCircle className="h-3 w-3" />
                            </button>
                          </div>
                        ))}
                      </div>
                      <input type="file" multiple accept="image/*" onChange={e => setImageFiles(e.target.files)} className="mt-3 block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-semibold file:bg-amber-50 file:text-amber-700 hover:file:bg-amber-100" />
                    </div>
                  </div>
                </div>
                <div className="bg-gray-50 px-4 py-3 sm:px-6 sm:flex sm:flex-row-reverse border-t border-gray-200">
                  <button type="submit" disabled={saving} className="w-full inline-flex justify-center rounded-md border border-transparent shadow-sm px-4 py-2 bg-amber-600 text-base font-medium text-white hover:bg-amber-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-amber-500 sm:ml-3 sm:w-auto sm:text-sm">
                    {saving ? 'Saving...' : 'Save'}
                  </button>
                  <button type="button" onClick={() => setIsModalOpen(false)} className="mt-3 w-full inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-base font-medium text-gray-700 hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-amber-500 sm:mt-0 sm:ml-3 sm:w-auto sm:text-sm">
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
