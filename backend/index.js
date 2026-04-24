const express = require('express');
const cors = require('cors');
const { createClient } = require('@supabase/supabase-js');

const app = express();
const PORT = process.env.PORT || 3001;

// Supabase client
const supabaseUrl = process.env.SUPABASE_URL || '';
const supabaseKey = process.env.SUPABASE_ANON_KEY || '';
const supabase = createClient(supabaseUrl, supabaseKey);

app.use(cors());
app.use(express.json());

// Health check
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Deployments endpoints
app.get('/api/deployments', async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('deployments')
      .select('*')
      .order('created_at', { ascending: false });
    
    if (error) throw error;
    res.json(data);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/deployments', async (req, res) => {
  try {
    const { name, url, status, project } = req.body;
    const { data, error } = await supabase
      .from('deployments')
      .insert([{ name, url, status: status || 'pending', project, created_at: new Date().toISOString() }])
      .select();
    
    if (error) throw error;
    res.json(data[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.patch('/api/deployments/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { status, url } = req.body;
    const { data, error } = await supabase
      .from('deployments')
      .update({ status, url, updated_at: new Date().toISOString() })
      .eq('id', id)
      .select();
    
    if (error) throw error;
    res.json(data[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Real-time subscriptions
app.get('/api/deployments/subscribe', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  
  const channel = supabase
    .channel('deployments')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'deployments' }, (payload) => {
      res.write(`data: ${JSON.stringify(payload)}\n\n`);
    })
    .subscribe();

  req.on('close', () => {
    supabase.removeChannel(channel);
  });
});

app.listen(PORT, () => {
  console.log(`Backend running on port ${PORT}`);
});

module.exports = app;
