import React, { useEffect, useState } from 'react';
import { collection, query, where, getDocs, updateDoc, doc } from 'firebase/firestore';
import { db } from '../lib/firebase';
import { Users, FileText, Music, Link as LinkIcon, CheckCircle, XCircle } from 'lucide-react';
import { Link } from 'react-router-dom';

export default function Dashboard() {
  const [stats, setStats] = useState({
    pendingUsers: 0,
    totalWordCards: 0,
    totalNewsletters: 0,
    totalPraise: 0
  });

  const [pendingUserList, setPendingUserList] = useState<any[]>([]);

  useEffect(() => {
    const fetchStats = async () => {
      // Fetch pending users
      const usersQuery = query(collection(db, 'users'), where('isApproved', '==', false));
      const usersSnap = await getDocs(usersQuery);
      setPendingUserList(usersSnap.docs.map(doc => ({ id: doc.id, ...doc.data() })));
      
      // We don't have accurate counts without reading all docs or maintaining a counter
      // This is a simplified fetch just to show some numbers
      try {
        const cardsSnap = await getDocs(collection(db, 'wordCards'));
        const newsSnap = await getDocs(collection(db, 'newsletters'));
        const praiseSnap = await getDocs(collection(db, 'praise'));
        
        setStats({
          pendingUsers: usersSnap.size,
          totalWordCards: cardsSnap.size,
          totalNewsletters: newsSnap.size,
          totalPraise: praiseSnap.size
        });
      } catch (err) {
        console.error("Error fetching collections. They might not exist yet.", err);
        setStats(prev => ({ ...prev, pendingUsers: usersSnap.size }));
      }
    };
    fetchStats();
  }, []);

  const handleApprove = async (userId: string) => {
    try {
      await updateDoc(doc(db, 'users', userId), {
        isApproved: true,
        updatedAt: new Date()
      });
      setPendingUserList(prev => prev.filter(u => u.id !== userId));
      setStats(prev => ({ ...prev, pendingUsers: prev.pendingUsers - 1 }));
    } catch (err) {
      alert("Failed to approve user.");
    }
  };

  const dashboardCards = [
    { title: 'Pending Users', count: stats.pendingUsers, icon: Users, color: 'bg-orange-500', link: '/users' },
    { title: 'Word Cards', count: stats.totalWordCards, icon: FileText, color: 'bg-blue-500', link: '/wordcards' },
    { title: 'Newsletters', count: stats.totalNewsletters, icon: FileText, color: 'bg-green-500', link: '/newsletters' },
    { title: 'Praise Items', count: stats.totalPraise, icon: Music, color: 'bg-purple-500', link: '/praise' },
  ];

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <h1 className="text-2xl font-bold text-gray-900">Dashboard Overview</h1>
      </div>

      <div className="grid grid-cols-1 gap-5 sm:grid-cols-2 lg:grid-cols-4">
        {dashboardCards.map((card) => {
          const Icon = card.icon;
          return (
            <Link key={card.title} to={card.link} className="bg-white overflow-hidden shadow rounded-lg hover:shadow-md transition">
              <div className="p-5">
                <div className="flex items-center">
                  <div className="flex-shrink-0">
                    <div className={`p-3 rounded-md ${card.color}`}>
                      <Icon className="h-6 w-6 text-white" />
                    </div>
                  </div>
                  <div className="ml-5 w-0 flex-1">
                    <dl>
                      <dt className="text-sm font-medium text-gray-500 truncate">{card.title}</dt>
                      <dd className="text-3xl font-semibold text-gray-900">{card.count}</dd>
                    </dl>
                  </div>
                </div>
              </div>
              <div className="bg-gray-50 px-5 py-3">
                <div className="text-sm text-gray-500 flex items-center">
                  <span className="text-sm">Manage</span>
                  <LinkIcon className="ml-1 h-3 w-3" />
                </div>
              </div>
            </Link>
          );
        })}
      </div>

      <div className="bg-white shadow rounded-lg mb-8">
        <div className="px-4 py-5 border-b border-gray-200 sm:px-6 flex justify-between items-center">
          <h3 className="text-lg leading-6 font-medium text-gray-900">
            Pending User Approvals
          </h3>
          <Link to="/users" className="text-sm text-amber-600 hover:text-amber-900">View all users</Link>
        </div>
        <div className="overflow-x-auto">
          {pendingUserList.length === 0 ? (
            <div className="p-6 text-center text-gray-500">No pending users</div>
          ) : (
            <table className="min-w-full divide-y divide-gray-200">
              <thead className="bg-gray-50">
                <tr>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Name</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Email</th>
                  <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Church</th>
                  <th className="px-6 py-3 text-right text-xs font-medium text-gray-500 uppercase tracking-wider">Actions</th>
                </tr>
              </thead>
              <tbody className="bg-white divide-y divide-gray-200">
                {pendingUserList.map((user) => (
                  <tr key={user.id}>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm font-medium text-gray-900">{user.name}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap">
                      <div className="text-sm text-gray-500">{user.email}</div>
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                      {user.churchName} ({user.churchCountry})
                    </td>
                    <td className="px-6 py-4 whitespace-nowrap text-right text-sm font-medium">
                      <button
                        onClick={() => handleApprove(user.id)}
                        className="text-green-600 hover:text-green-900 flex items-center justify-end w-full"
                      >
                        <CheckCircle className="h-4 w-4 mr-1" /> Approve
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      </div>
    </div>
  );
}
