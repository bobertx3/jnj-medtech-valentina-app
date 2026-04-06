import React, { useState, useRef, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, Legend } from 'recharts';
import './App.css';

const ALL_SUGGESTIONS = [
  "How many candidates are currently in the pipeline?",
  "What is the average time to fill a position?",
  "Which department has the most open positions?",
  "Who are the top recruiters by positions filled?",
  "What is the average offer amount by department?",
  "Show candidate pipeline breakdown by stage",
  "Which sourcing channel has the most hires?",
  "What is the cost per hire by department?",
  "Which business unit has the most candidates?",
  "What is the average candidate satisfaction score?",
];

const CHART_COLORS = ['#0077B6', '#1565C0', '#2E7D32', '#E65100', '#6A1B9A', '#00838F'];

function pickSuggestions(count = 3, exclude = '') {
  const filtered = ALL_SUGGESTIONS.filter(s => s !== exclude);
  const shuffled = [...filtered].sort(() => Math.random() - 0.5);
  return shuffled.slice(0, count);
}

function AutoChart({ columns, data }) {
  if (!columns || !data || data.length === 0) return null;

  // Single row — skip visualization (answer is already in the text)
  if (data.length === 1) return null;

  // Too many rows
  if (data.length > 15) return null;

  // Detect string vs numeric columns
  const colTypes = columns.map((col, i) => {
    const sample = data[0][i];
    return { name: col, idx: i, isNumeric: sample !== null && sample !== '' && !isNaN(parseFloat(sample)) };
  });
  const stringCols = colTypes.filter(c => !c.isNumeric);
  const numericCols = colTypes.filter(c => c.isNumeric);

  if (stringCols.length === 0 || numericCols.length === 0) return null;

  // Build chart data
  const chartData = data.map(row => {
    const obj = { [stringCols[0].name]: row[stringCols[0].idx] };
    numericCols.forEach(nc => { obj[nc.name] = parseFloat(row[nc.idx]) || 0; });
    return obj;
  });

  return (
    <div className="auto-chart">
      <ResponsiveContainer width="100%" height={Math.max(200, data.length * 36 + 40)}>
        <BarChart data={chartData} layout="vertical" margin={{ left: 20, right: 20, top: 5, bottom: 5 }}>
          <CartesianGrid strokeDasharray="3 3" horizontal={false} />
          <XAxis type="number" tick={{ fontSize: 12 }} />
          <YAxis type="category" dataKey={stringCols[0].name} width={140} tick={{ fontSize: 12 }} />
          <Tooltip formatter={(value) => value.toLocaleString()} />
          {numericCols.length > 1 && <Legend />}
          {numericCols.map((nc, i) => (
            <Bar key={nc.name} dataKey={nc.name} fill={CHART_COLORS[i % CHART_COLORS.length]} radius={[0, 4, 4, 0]} />
          ))}
        </BarChart>
      </ResponsiveContainer>
    </div>
  );
}

function App() {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [conversationId, setConversationId] = useState(null);
  const [showWelcome, setShowWelcome] = useState(true);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const [followUps, setFollowUps] = useState([]);
  const chatRef = useRef(null);

  useEffect(() => {
    if (chatRef.current) {
      chatRef.current.scrollTop = chatRef.current.scrollHeight;
    }
  }, [messages, loading, followUps]);

  const sendMessage = async (text) => {
    const msg = text || input.trim();
    if (!msg || loading) return;

    setShowWelcome(false);
    setFollowUps([]);
    setMessages(prev => [...prev, { role: 'user', content: msg }]);
    setInput('');
    setLoading(true);

    try {
      const resp = await fetch('/api/chat', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ message: msg, conversation_id: conversationId }),
      });
      const data = await resp.json();
      if (resp.ok) {
        setConversationId(data.conversation_id);
        setMessages(prev => [...prev, {
          role: 'assistant',
          content: data.reply,
          sql: data.sql,
          data: data.data,
          columns: data.columns,
        }]);
        setFollowUps(pickSuggestions(3, msg));
      } else {
        setMessages(prev => [...prev, {
          role: 'assistant',
          content: `Sorry, I encountered an error: ${data.detail || 'Unknown error'}`,
        }]);
        setFollowUps(pickSuggestions(3, msg));
      }
    } catch (e) {
      setMessages(prev => [...prev, {
        role: 'assistant',
        content: 'Sorry, I could not connect to the server. Please try again.',
      }]);
    } finally {
      setLoading(false);
    }
  };

  const resetChat = () => {
    setMessages([]);
    setConversationId(null);
    setShowWelcome(true);
    setFollowUps([]);
  };

  return (
    <div className="app">
      <header className="header">
        <div className="header-left">
          <button className="header-toggle" onClick={() => setSidebarCollapsed(!sidebarCollapsed)} title="Toggle sidebar">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="9" y1="3" x2="9" y2="21"/></svg>
          </button>
          <span className="brand">J&J HR Recruiting</span>
        </div>
        <div className="header-right">
          <span className="title">Ask Genie</span>
        </div>
      </header>

      <div className="layout">
        <aside className={`sidebar ${sidebarCollapsed ? 'collapsed' : ''}`}>
          <nav className="nav-items">
            <div className="nav-item active">
              <span className="icon">&#128172;</span><span className="nav-label">Chat</span>
            </div>
            <div className="nav-item">
              <span className="icon">&#128202;</span><span className="nav-label">Dashboard</span>
            </div>
          </nav>
        </aside>

        <main className="main">
          <div className="main-header">
            <h2>Chat</h2>
            <div className="actions">
              <button className="action-btn" title="Download">&#11015;</button>
              <button className="action-btn" title="New Chat" onClick={resetChat}>&#10010;</button>
            </div>
          </div>

          <div className="chat-area" ref={chatRef}>
            <div className="info-banner">
              Genie provides instant, data-driven insights by querying live HR recruiting and talent acquisition datasets.
            </div>

            {showWelcome && (
              <>
                <div className="welcome">
                  <div className="avatar-large">G</div>
                  <h3>What's on your mind?</h3>
                  <p>Welcome to Chat. How may I help you?</p>
                  <a className="faq-link" href="#faq">Go to FAQs &#x1F6C8;</a>
                </div>
                <div className="suggestions">
                  {ALL_SUGGESTIONS.slice(0, 4).map((s, i) => (
                    <button key={i} className="suggestion-card" onClick={() => sendMessage(s)}>
                      {s}
                    </button>
                  ))}
                </div>
              </>
            )}

            {messages.map((msg, i) => (
              <Message key={i} {...msg} />
            ))}

            {!loading && followUps.length > 0 && (
              <div className="follow-up-suggestions">
                {followUps.map((s, i) => (
                  <button key={i} className="follow-up-card" onClick={() => sendMessage(s)}>
                    {s}
                  </button>
                ))}
              </div>
            )}

            {loading && (
              <div className="message assistant">
                <div className="msg-avatar">G</div>
                <div className="msg-content">
                  <div className="loading">
                    <div className="dot" />
                    <div className="dot" />
                    <div className="dot" />
                  </div>
                </div>
              </div>
            )}
          </div>

          <div className="input-area">
            <div className="input-row">
              <button className="mic-btn" title="Voice input">&#127908;</button>
              <input
                type="text"
                value={input}
                onChange={e => setInput(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && sendMessage()}
                placeholder="Click mic to ask or you can type ..."
              />
              <button
                className="send-btn"
                onClick={() => sendMessage()}
                disabled={loading || !input.trim()}
                title="Send"
              >
                &#9654;
              </button>
            </div>
          </div>
          <div className="disclaimer">
            Ask Genie is J&J HR Recruiting's Gen AI application, restricted to J&J associates. It may provide inaccurate information about people, places, or facts. Please refer to <a href="#guidelines">J&J AI Guidelines</a>.
          </div>
        </main>
      </div>
    </div>
  );
}

function Message({ role, content, sql, data, columns }) {
  const [showSql, setShowSql] = useState(false);

  if (role === 'user') {
    return (
      <div className="message user">
        <div className="msg-content">{content}</div>
      </div>
    );
  }

  return (
    <div className="message assistant">
      <div className="msg-avatar">G</div>
      <div className="msg-content">
        <ReactMarkdown remarkPlugins={[remarkGfm]}>{content}</ReactMarkdown>
        <AutoChart columns={columns} data={data} />
        {sql && (
          <>
            <span className="sql-toggle" onClick={() => setShowSql(!showSql)}>
              &#128269; {showSql ? 'Hide' : 'View'} SQL
            </span>
            {showSql && <pre className="sql-block">{sql}</pre>}
          </>
        )}
      </div>
    </div>
  );
}

export default App;
