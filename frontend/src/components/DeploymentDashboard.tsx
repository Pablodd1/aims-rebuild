'use client';

import { useState, useEffect } from 'react';

interface Deployment {
  id: string;
  name: string;
  url: string;
  status: 'pending' | 'building' | 'deployed' | 'failed';
  project: string;
  created_at: string;
}

export default function DeploymentDashboard() {
  const [deployments, setDeployments] = useState<Deployment[]>([]);
  const [loading, setLoading] = useState(true);
  const [newDeploy, setNewDeploy] = useState({ name: '', url: '', project: '' });

  useEffect(() => {
    fetchDeployments();
    const interval = setInterval(fetchDeployments, 5000);
    return () => clearInterval(interval);
  }, []);

  const fetchDeployments = async () => {
    try {
      const res = await fetch('/api/deployments');
      if (res.ok) {
        const data = await res.json();
        setDeployments(data);
      }
    } catch (err) {
      console.error('Failed to fetch deployments');
    } finally {
      setLoading(false);
    }
  };

  const createDeployment = async () => {
    try {
      const res = await fetch('/api/deployments', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...newDeploy, status: 'pending' }),
      });
      if (res.ok) {
        setNewDeploy({ name: '', url: '', project: '' });
        fetchDeployments();
      }
    } catch (err) {
      console.error('Failed to create deployment');
    }
  };

  const getStatusColor = (status: string) => {
    switch (status) {
      case 'deployed': return 'bg-green-500';
      case 'building': return 'bg-yellow-500';
      case 'pending': return 'bg-gray-500';
      case 'failed': return 'bg-red-500';
      default: return 'bg-gray-400';
    }
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white p-8">
      <h1 className="text-3xl font-bold mb-8">Real-Time Deployments</h1>
      
      {/* Create Deployment Form */}
      <div className="bg-gray-800 rounded-lg p-6 mb-8">
        <h2 className="text-xl font-semibold mb-4">New Deployment</h2>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          <input
            type="text"
            placeholder="Deployment Name"
            value={newDeploy.name}
            onChange={(e) => setNewDeploy({ ...newDeploy, name: e.target.value })}
            className="bg-gray-700 rounded px-4 py-2 text-white"
          />
          <input
            type="text"
            placeholder="Project"
            value={newDeploy.project}
            onChange={(e) => setNewDeploy({ ...newDeploy, project: e.target.value })}
            className="bg-gray-700 rounded px-4 py-2 text-white"
          />
          <input
            type="text"
            placeholder="URL (optional)"
            value={newDeploy.url}
            onChange={(e) => setNewDeploy({ ...newDeploy, url: e.target.value })}
            className="bg-gray-700 rounded px-4 py-2 text-white"
          />
        </div>
        <button
          onClick={createDeployment}
          className="mt-4 bg-blue-600 hover:bg-blue-700 px-6 py-2 rounded font-semibold"
        >
          Deploy
        </button>
      </div>

      {/* Deployments List */}
      {loading ? (
        <p>Loading...</p>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {deployments.map((deploy) => (
            <div key={deploy.id} className="bg-gray-800 rounded-lg p-6">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-lg font-semibold">{deploy.name}</h3>
                <span className={`${getStatusColor(deploy.status)} px-3 py-1 rounded-full text-sm`}>
                  {deploy.status}
                </span>
              </div>
              <p className="text-gray-400 text-sm mb-2">{deploy.project}</p>
              {deploy.url && (
                <a href={deploy.url} target="_blank" rel="noopener noreferrer" className="text-blue-400 text-sm hover:underline">
                  {deploy.url}
                </a>
              )}
              <p className="text-gray-500 text-xs mt-4">
                {new Date(deploy.created_at).toLocaleString()}
              </p>
            </div>
          ))}
        </div>
      )}

      {deployments.length === 0 && !loading && (
        <p className="text-gray-400">No deployments yet. Create one above!</p>
      )}
    </div>
  );
}
