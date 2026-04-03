import React, { useState, useRef, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import './App.css';

const SUGGESTIONS = [
  "Which account has the highest Opportunity ($)?",
  "What are the top 5 HCPs based on procedure volume for this year?",
  "Which Product Line has the highest total Opportunity ($)?",
  "Which GPO has the highest opportunity?",
];

function App() {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [loading, setLoading] = useState(false);
  const [conversationId, setConversationId] = useState(null);
  const [showWelcome, setShowWelcome] = useState(true);
  const [sidebarCollapsed, setSidebarCollapsed] = useState(false);
  const chatRef = useRef(null);

  useEffect(() => {
    if (chatRef.current) {
      chatRef.current.scrollTop = chatRef.current.scrollHeight;
    }
  }, [messages, loading]);

  const sendMessage = async (text) => {
    const msg = text || input.trim();
    if (!msg || loading) return;

    setShowWelcome(false);
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
        }]);
      } else {
        setMessages(prev => [...prev, {
          role: 'assistant',
          content: `Sorry, I encountered an error: ${data.detail || 'Unknown error'}`,
        }]);
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
  };

  return (
    <div className="app">
      {/* Header */}
      <header className="header">
        <div className="header-left">
          <button className="header-toggle" onClick={() => setSidebarCollapsed(!sidebarCollapsed)} title="Toggle sidebar">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"/><line x1="9" y1="3" x2="9" y2="21"/></svg>
          </button>
          <span className="brand">J&J MedTech</span>
        </div>
        <div className="header-right">
          <span className="title">Ask Genie</span>
        </div>
      </header>

      <div className="layout">
        {/* Sidebar */}
        <aside className={`sidebar ${sidebarCollapsed ? 'collapsed' : ''}`}>
          <nav className="nav-items">
            <div className="nav-item active">
              <span className="icon">&#128172;</span><span className="nav-label">Chat</span>
            </div>
            <div className="nav-item">
              <span className="icon">&#128202;</span><span className="nav-label">Dashboard</span>
            </div>
            <div className="nav-item">
              <span className="icon">&#128222;</span><span className="nav-label"><a href="tel:301-908-5817" style={{color:'inherit',textDecoration:'none'}}>Contact Center</a></span>
            </div>
          </nav>
        </aside>

        {/* Main */}
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
              Genie provides instant, data-driven insights by querying live clinical and commercial datasets.
            </div>

            {showWelcome && (
              <>
                <div className="welcome">
                  <div className="avatar-large">V</div>
                  <h3>Hi Valentina!</h3>
                  <p>Welcome to Chat. How may I help you?</p>
                  <a className="faq-link" href="#faq">Go to FAQs &#x1F6C8;</a>
                </div>
                <div className="suggestions">
                  {SUGGESTIONS.map((s, i) => (
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

            {loading && (
              <div className="message assistant">
                <div className="msg-avatar">V</div>
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
            Ask Genie is J&J MedTech's Gen AI application, restricted to J&J associates. It may provide inaccurate information about people, places, or facts. Please refer to <a href="#guidelines">J&J AI Guidelines</a>.
          </div>
        </main>
      </div>
    </div>
  );
}

function Message({ role, content, sql }) {
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
      <div className="msg-avatar">V</div>
      <div className="msg-content">
        <ReactMarkdown remarkPlugins={[remarkGfm]}>{content}</ReactMarkdown>
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
