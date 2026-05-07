// v3 — bolder, listening more carefully

const N = ({ top, left, right, width = 160, children }) => (
  <div className="note3" style={{ top, left, right, width }}>{children}</div>
);

/* ──────────────────────────────────────────────────────────
   1. COLOR COMPARISON — d1 vs d2 side-by-side
   ────────────────────────────────────────────────────────── */
const ColorCompare = () => (
  <DCSection id="color-v3" title="Pick a side · indigo+amber vs red+gold">
    <DCArtboard id="col-d1" label="D1 · Indigo chrome + amber energy" width={540} height={460}>
      <ColorSpec dir="d1"/>
    </DCArtboard>
    <DCArtboard id="col-d2" label="D2 · Black + signature red (v1, fixed)" width={540} height={460}>
      <ColorSpec dir="d2"/>
    </DCArtboard>
  </DCSection>
);

const ColorSpec = ({ dir }) => {
  const palettes = {
    d1: {
      title: 'INDIGO + AMBER',
      desc:  'Calm chrome (indigo) for nav and structure. Warm amber + orange punch in for the moments that matter — winners, big scores, "now throwing". Boring on purpose, so the energy reads.',
      sw: [
        {l:'CHROME', v:'#4F5DC4'}, {l:'CHROME-C', v:'#DFE0FF'},
        {l:'ENERGY', v:'#FFB300'}, {l:'ENERGY-2', v:'#FF6B35'},
        {l:'BG', v:'#14141A'}, {l:'BG-2', v:'#21222B'},
      ],
      board: ['#2E7D32','#C62828'],
      boardLabel: 'TRUE BOARD COLORS',
    },
    d2: {
      title: 'BLACK + SIGNATURE RED',
      desc:  'Your v1 identity, kept. Red is the brand voice — energy and chrome both. Fix from v1: the dartboard sectors get desaturated so they don\'t fight the brand red.',
      sw: [
        {l:'CHROME', v:'#d94234'}, {l:'ENERGY', v:'#FFD700'},
        {l:'BG', v:'#0c0c0c'}, {l:'BG-2', v:'#1e1e26'},
        {l:'BOARD-S', v:'#4a6b4f'}, {l:'BOARD-T', v:'#6b3a3a'},
      ],
      board: ['#4a6b4f','#6b3a3a'],
      boardLabel: 'DESATURATED BOARD',
    },
  };
  const p = palettes[dir];
  return (
    <div className={`tab3 ${dir}`} style={{height:460}}>
      <div className="dot"/>
      <div style={{padding:18}}>
        <div className="label-tiny">{p.title}</div>
        <div style={{fontFamily:'var(--display)', fontSize:34, lineHeight:0.9, marginTop:6}}>{p.title}</div>
        <div className="label-tiny" style={{marginTop:10, fontFamily:'var(--sans)', letterSpacing:0, fontSize:12, lineHeight:1.5, fontWeight:400, textTransform:'none'}}>
          {p.desc}
        </div>
      </div>
      <div style={{padding:'0 18px', display:'grid', gridTemplateColumns:'repeat(3, 1fr)', gap:8}}>
        {p.sw.map(s => (
          <div key={s.l}>
            <div style={{height:42, borderRadius:6, background:s.v, border:'1px solid rgba(255,255,255,0.1)'}}/>
            <div style={{fontFamily:'var(--mono)', fontSize:9, letterSpacing:1, marginTop:4, opacity:0.7}}>{s.l}</div>
            <div style={{fontFamily:'var(--mono)', fontSize:10}}>{s.v}</div>
          </div>
        ))}
      </div>
      <div style={{padding:18, display:'flex', gap:14, alignItems:'center'}}>
        <div className="board3" style={{width:90, height:90, flexShrink:0}}/>
        <div>
          <div className="label-tiny">{p.boardLabel}</div>
          <div style={{fontSize:11, marginTop:4, lineHeight:1.4, opacity:0.8}}>
            {dir==='d1'
              ? 'Real green/red on the input — UI chrome stays out of dartboard semantics.'
              : 'Muted sectors keep brand red dominant. Players still see green=single, red=triple, just quieter.'}
          </div>
        </div>
      </div>
      <div style={{padding:'0 18px 18px', display:'flex', gap:8}}>
        <div className="btn3 primary">START GAME</div>
        <div className="btn3 ghost">SETTINGS</div>
        <div className="btn3 outline">UNDO</div>
      </div>
    </div>
  );
};

/* ──────────────────────────────────────────────────────────
   2. X01 — revert to v1 stadium D + small persistent strip
   ────────────────────────────────────────────────────────── */
const X01v3 = () => (
  <DCSection id="x01-v3" title="X01 in-game · v1 stadium reverted, with a small player strip">
    <DCArtboard id="x01-d1" label="D1 · Indigo+amber" width={540} height={720}><X01Stadium3 dir="d1"/></DCArtboard>
    <DCArtboard id="x01-d2" label="D2 · Red (your v1)" width={540} height={720}><X01Stadium3 dir="d2"/></DCArtboard>
  </DCSection>
);

const X01Stadium3 = ({ dir }) => {
  const energyColor = dir==='d1' ? 'var(--d1-energy)' : 'var(--d2-energy)';
  const chromeColor = dir==='d1' ? 'var(--d1-energy-2)' : 'var(--d2-chrome)';
  return (
    <div className={`tab3 ${dir}`}>
      <div className="dot"/>
      {/* Top broadcast strip */}
      <div className="broadcast">
        <div className="live">LIVE</div>
        <div className="meta">501 · DOUBLE-OUT · ROUND 7 · LEG 1</div>
        <div style={{padding:'8px 14px'}}>⚙</div>
      </div>

      {/* NOW THROWING — full bleed, big */}
      <div className="now-throw">
        <div className="label-tiny">NOW THROWING</div>
        <div style={{display:'flex', alignItems:'center', gap:14, marginTop:6}}>
          <div className="av3 lg energy">A</div>
          <div style={{flex:1}}>
            <div style={{fontFamily:'var(--display)', fontSize:30, lineHeight:0.9, letterSpacing:0}}>ANDREAS</div>
            <div style={{display:'flex', gap:6, marginTop:8, alignItems:'center'}}>
              {[1,2,3].map(i => (
                <div key={i} style={{width:32, height:6, borderRadius:3, background:i<=2?chromeColor:'rgba(255,255,255,0.1)'}}/>
              ))}
              <div className="label-tiny" style={{marginLeft:6}}>2/3</div>
            </div>
          </div>
          <div style={{textAlign:'right'}}>
            <div className="score-huge">120</div>
          </div>
        </div>
        <div style={{display:'flex', justifyContent:'space-between', marginTop:10, fontSize:11, borderTop:'1px dashed rgba(255,255,255,0.15)', paddingTop:8}}>
          <div><span className="label-tiny">TURN</span> <span style={{fontWeight:700, marginLeft:4}}>+60</span></div>
          <div><span className="label-tiny">LAST</span> <span style={{fontWeight:700, marginLeft:4}}>T20</span></div>
          <div><span className="label-tiny">AVG</span> <span style={{fontWeight:700, marginLeft:4}}>78.4</span></div>
          <div style={{color:energyColor, fontWeight:800, fontFamily:'var(--mono)'}}>↪ T20·D20</div>
        </div>
      </div>

      {/* Other players — small persistent strip */}
      <div className="players-strip">
        {[
          {n:'JONAS', s:284, d:'+45'},
          {n:'MIA',   s:340, d:'-'},
          {n:'ERIK',  s:412, d:'+80'},
        ].map((p,i)=>(
          <div key={i}>
            <div className="label-tiny">{p.n}</div>
            <div style={{fontFamily:'var(--display)', fontSize:24, lineHeight:1, marginTop:2}}>{p.s}</div>
            <div className="label-tiny" style={{fontSize:9}}>turn {p.d}</div>
          </div>
        ))}
      </div>

      {/* Big board */}
      <div style={{padding:'14px 20px', flex:1, display:'flex', alignItems:'center', justifyContent:'center', position:'relative'}}>
        <div className="board3" style={{width:'88%'}}/>
        <div className="label-tiny" style={{position:'absolute', top:14, left:30, fontSize:9}}>● TAP TO SCORE</div>
      </div>

      {/* Footer */}
      <div style={{padding:'10px 12px', display:'flex', gap:8, alignItems:'center', borderTop:'1px solid', borderColor: dir==='d1' ? 'var(--d1-line)' : 'var(--d2-line)'}}>
        <div className="btn3 ghost">MISS</div>
        <div className="btn3 outline">↶ UNDO</div>
        <div style={{flex:1}}/>
        <div className="btn3 primary">END TURN</div>
      </div>

      <N top={210} right={-160} width={150}>v1 D restored: big board, big score, broadcast feel.</N>
      <N top={290} left={-150} width={140}>Players strip — small, persistent, three glance-friendly cells.</N>
    </div>
  );
};

/* ──────────────────────────────────────────────────────────
   3. CRICKET — numbers as the input. NO dartboard.
   ────────────────────────────────────────────────────────── */
const Cricketv3 = () => (
  <DCSection id="cricket-v3" title="Cricket · numbers ARE the input">
    <DCArtboard id="crk-grid7" label="A · 7-target grid + S/D/T" width={540} height={720}><CrkGrid7/></DCArtboard>
    <DCArtboard id="crk-rows"  label="B · Big number rows" width={540} height={720}><CrkRows/></DCArtboard>
    <DCArtboard id="crk-stand" label="C · 3-column standings" width={540} height={720}><CrkStandings/></DCArtboard>
  </DCSection>
);

// Mock cricket state
const cricketState = {
  active: 'A',
  multiplier: 'T', // currently armed
  players: [
    {id:'A', n:'Andreas', pts:40, marks:{20:3, 19:2, 18:0, 17:0, 16:0, 15:0, B:0}},
    {id:'J', n:'Jonas',   pts:15, marks:{20:1, 19:3, 18:0, 17:0, 16:0, 15:0, B:0}},
    {id:'M', n:'Mia',     pts:0,  marks:{20:0, 19:0, 18:1, 17:0, 16:0, 15:0, B:0}},
  ],
};

const targets = [20,19,18,17,16,15,'B'];

// "Mark" indicator — / for 1, X for 2, ⊕/closed for 3
const MarkGlyph = ({ count, color }) => {
  if (count === 0) return <span style={{opacity:0.2}}>·</span>;
  if (count === 1) return <span style={{color, fontWeight:800}}>/</span>;
  if (count === 2) return <span style={{color, fontWeight:800}}>X</span>;
  return <span style={{color, fontWeight:800}}>⊘</span>;
};

const CrkGrid7 = () => (
  <div className="tab3 d1">
    <div className="dot"/>
    <div className="broadcast">
      <div className="live">CRICKET</div>
      <div className="meta">ROUND 3 · ANDREAS</div>
      <div style={{padding:'8px 14px'}}>⚙</div>
    </div>

    {/* Standings header */}
    <div className="players-strip">
      {cricketState.players.map(p => (
        <div key={p.id} style={{background: p.id===cricketState.active ? 'rgba(255,179,0,0.10)' : 'transparent'}}>
          <div className="label-tiny">{p.n.toUpperCase()}</div>
          <div style={{fontFamily:'var(--display)', fontSize:26, lineHeight:1, marginTop:2, color: p.id===cricketState.active ? 'var(--d1-energy)' : 'var(--d1-text)'}}>{p.pts}</div>
          <div className="label-tiny" style={{fontSize:9}}>pts</div>
        </div>
      ))}
    </div>

    {/* Target grid — big numbers, three columns of marks per target */}
    <div style={{padding:'12px 14px', flex:1, display:'flex', flexDirection:'column', gap:6}}>
      <div style={{display:'grid', gridTemplateColumns:'56px 1fr 1fr 1fr', gap:6, fontFamily:'var(--mono)', fontSize:9, letterSpacing:1.5, color:'var(--d1-text-v)', padding:'0 4px'}}>
        <div></div>
        <div style={{textAlign:'center'}}>A</div>
        <div style={{textAlign:'center'}}>J</div>
        <div style={{textAlign:'center'}}>M</div>
      </div>
      {targets.map(t => {
        const allClosed = cricketState.players.every(p => p.marks[t] >= 3);
        return (
          <div key={t} style={{display:'grid', gridTemplateColumns:'56px 1fr 1fr 1fr', gap:6, alignItems:'stretch'}}>
            {/* Number — TAP HERE to log a hit */}
            <div style={{
              display:'flex', alignItems:'center', justifyContent:'center',
              background: 'var(--d1-bg-2)',
              border: '1.5px solid var(--d1-line)',
              borderRadius: 8,
              fontFamily:'var(--display)', fontSize: 26,
              color: allClosed ? 'var(--d1-text-v)' : 'var(--d1-text)',
              textDecoration: allClosed ? 'line-through' : 'none',
            }}>{t}</div>
            {cricketState.players.map(p => {
              const m = p.marks[t];
              const closed = m >= 3;
              return (
                <div key={p.id} style={{
                  background: closed ? 'var(--d1-energy)' : (m>0 ? 'rgba(255,179,0,0.10)' : 'var(--d1-bg-1)'),
                  borderRadius: 8,
                  border: '1px solid var(--d1-line)',
                  display:'flex', alignItems:'center', justifyContent:'center',
                  fontSize: 22,
                  color: closed ? '#000' : 'var(--d1-text)',
                }}>
                  <MarkGlyph count={m} color={closed ? '#000' : 'var(--d1-energy)'}/>
                </div>
              );
            })}
          </div>
        );
      })}
    </div>

    {/* Multiplier picker — armed before tapping a number */}
    <div style={{padding:'10px 14px', borderTop:'1px solid var(--d1-line)', background:'var(--d1-bg-1)'}}>
      <div className="label-tiny" style={{marginBottom:6}}>ANDREAS · DART 2/3 · ARM MULTIPLIER → TAP TARGET</div>
      <div style={{display:'flex', gap:6}}>
        {['S','D','T'].map(m => (
          <div key={m} style={{
            flex:1, padding:'12px 0', textAlign:'center',
            background: m==='T' ? 'var(--d1-energy)' : 'var(--d1-bg-2)',
            color: m==='T' ? '#000' : 'var(--d1-text)',
            borderRadius:8,
            fontFamily:'var(--display)', fontSize:22, fontWeight:600,
            border: '1.5px solid ' + (m==='T' ? 'var(--d1-energy)' : 'var(--d1-line)'),
          }}>{m==='S'?'SINGLE':m==='D'?'DOUBLE':'TRIPLE'}</div>
        ))}
      </div>
    </div>

    <div style={{padding:'10px 12px', display:'flex', gap:8}}>
      <div className="btn3 ghost">MISS</div>
      <div className="btn3 outline">↶ UNDO</div>
      <div style={{flex:1}}/>
      <div className="btn3 primary">END TURN</div>
    </div>

    <N top={140} right={-160} width={160}>Each row IS a number. Tap the big numeral to score — multiplier picker arms it. <strong>No dartboard needed</strong>.</N>
    <N top={420} left={-150} width={140}>Marks: <code>/</code> = 1, <code>X</code> = 2, <code>⊘</code> + amber fill = closed.</N>
  </div>
);

const CrkRows = () => (
  <div className="tab3 d1">
    <div className="dot"/>
    <div className="broadcast">
      <div className="live">CRICKET</div>
      <div className="meta">ROUND 3 · DART 2/3</div>
    </div>

    <div className="players-strip">
      {cricketState.players.map(p => (
        <div key={p.id} style={{background: p.id===cricketState.active ? 'rgba(255,179,0,0.10)' : 'transparent'}}>
          <div className="label-tiny">{p.n.toUpperCase()}</div>
          <div style={{fontFamily:'var(--display)', fontSize:24, color: p.id===cricketState.active ? 'var(--d1-energy)' : 'var(--d1-text)'}}>{p.pts}</div>
        </div>
      ))}
    </div>

    {/* Big number rows — each one tappable. Active player's marks shown inside */}
    <div style={{padding:'10px 12px', flex:1, display:'flex', flexDirection:'column', gap:5}}>
      {targets.map(t => {
        const me = cricketState.players[0];
        const m = me.marks[t];
        const closed = m >= 3;
        return (
          <div key={t} style={{
            flex:1, display:'flex', alignItems:'center', gap:10,
            padding:'0 16px',
            background: closed ? 'var(--d1-energy)' : 'var(--d1-bg-1)',
            color: closed ? '#000' : 'var(--d1-text)',
            borderRadius: 10,
            border: '1px solid ' + (closed ? 'var(--d1-energy)' : 'var(--d1-line)'),
          }}>
            <div style={{fontFamily:'var(--display)', fontSize:38, width:54}}>{t}</div>
            {/* My marks */}
            <div style={{display:'flex', gap:5}}>
              {[0,1,2].map(i => (
                <div key={i} style={{
                  width:22, height:22, borderRadius:5,
                  background: i<m ? (closed ? '#000' : 'var(--d1-energy)') : 'transparent',
                  border: '1.5px solid ' + (closed ? '#000' : 'var(--d1-line)'),
                }}/>
              ))}
            </div>
            {/* Opponents at-a-glance */}
            <div style={{flex:1, fontSize:10, fontFamily:'var(--mono)', textAlign:'right', opacity:0.7, letterSpacing:1}}>
              J: {cricketState.players[1].marks[t]>=3?'CLOSED':cricketState.players[1].marks[t]+'/3'}{' · '}
              M: {cricketState.players[2].marks[t]>=3?'CLOSED':cricketState.players[2].marks[t]+'/3'}
            </div>
          </div>
        );
      })}
    </div>

    {/* Multiplier */}
    <div style={{padding:'8px 12px', display:'flex', gap:6, borderTop:'1px solid var(--d1-line)', background:'var(--d1-bg-1)'}}>
      {['S','D','T'].map(m => (
        <div key={m} style={{
          flex:1, padding:'10px 0', textAlign:'center',
          background: m==='T' ? 'var(--d1-energy)' : 'var(--d1-bg-2)',
          color: m==='T' ? '#000' : 'var(--d1-text)',
          borderRadius:8,
          fontFamily:'var(--display)', fontSize:20,
        }}>{m}</div>
      ))}
    </div>

    <div style={{padding:'8px 12px', display:'flex', gap:8}}>
      <div className="btn3 ghost">MISS</div>
      <div className="btn3 outline">↶ UNDO</div>
      <div style={{flex:1}}/>
      <div className="btn3 primary">END TURN</div>
    </div>

    <N top={130} right={-150} width={140}>One big tappable row per number. Boxes = your marks. Opponents shown as text on the right.</N>
  </div>
);

const CrkStandings = () => (
  <div className="tab3 d1">
    <div className="dot"/>
    <div className="broadcast">
      <div className="live">CRICKET</div>
      <div className="meta">ROUND 3 · ANDREAS</div>
    </div>

    {/* Three columns: each column = one player + their progress per target */}
    <div style={{flex:1, display:'flex', padding:'10px 12px', gap:8}}>
      {cricketState.players.map(p => {
        const active = p.id === cricketState.active;
        return (
          <div key={p.id} style={{
            flex:1, display:'flex', flexDirection:'column',
            border: '1.5px solid ' + (active ? 'var(--d1-energy)' : 'var(--d1-line)'),
            borderRadius: 12,
            background: active ? 'rgba(255,179,0,0.05)' : 'var(--d1-bg-1)',
            overflow:'hidden',
          }}>
            <div style={{padding:'10px 10px 8px', borderBottom:'1px solid var(--d1-line)', textAlign:'center'}}>
              <div className="label-tiny" style={{color: active ? 'var(--d1-energy)' : undefined}}>{p.n.toUpperCase()}</div>
              <div style={{fontFamily:'var(--display)', fontSize:32, lineHeight:1, marginTop:2, color: active ? 'var(--d1-energy)' : 'var(--d1-text)'}}>{p.pts}</div>
            </div>
            <div style={{flex:1, display:'flex', flexDirection:'column'}}>
              {targets.map(t => {
                const m = p.marks[t];
                const closed = m >= 3;
                return (
                  <div key={t} style={{
                    flex:1, display:'flex', alignItems:'center', justifyContent:'space-between',
                    padding: '0 10px',
                    background: closed ? 'var(--d1-energy)' : 'transparent',
                    color: closed ? '#000' : 'var(--d1-text)',
                    borderBottom: '1px solid var(--d1-line)',
                  }}>
                    <div style={{fontFamily:'var(--display)', fontSize:18}}>{t}</div>
                    <div style={{display:'flex', gap:3}}>
                      {[0,1,2].map(i => (
                        <div key={i} style={{
                          width:12, height:12, borderRadius:3,
                          background: i<m ? (closed ? '#000' : 'var(--d1-energy)') : 'rgba(255,255,255,0.08)',
                          border: '1px solid ' + (closed ? '#000' : 'var(--d1-line)'),
                        }}/>
                      ))}
                    </div>
                  </div>
                );
              })}
            </div>
          </div>
        );
      })}
    </div>

    {/* Input area — number buttons + multiplier */}
    <div style={{padding:'10px 12px', borderTop:'1px solid var(--d1-line)', background:'var(--d1-bg-1)'}}>
      <div className="label-tiny" style={{marginBottom:6}}>ANDREAS · DART 2/3 · TAP NUMBER</div>
      <div style={{display:'grid', gridTemplateColumns:'repeat(7, 1fr)', gap:5, marginBottom:6}}>
        {targets.map(t => (
          <div key={t} style={{
            padding:'10px 0', textAlign:'center',
            background:'var(--d1-bg-2)', borderRadius:6,
            fontFamily:'var(--display)', fontSize:18,
            border:'1px solid var(--d1-line)',
          }}>{t}</div>
        ))}
      </div>
      <div style={{display:'flex', gap:5}}>
        {['SINGLE','DOUBLE','TRIPLE'].map((m,i) => (
          <div key={m} style={{
            flex:1, padding:'8px 0', textAlign:'center',
            background: i===2 ? 'var(--d1-energy)' : 'var(--d1-bg-2)',
            color: i===2 ? '#000' : 'var(--d1-text)',
            borderRadius:6,
            fontFamily:'var(--mono)', fontSize:11, fontWeight:800, letterSpacing:1.5,
          }}>{m}</div>
        ))}
      </div>
    </div>

    <N top={120} right={-150} width={140}>Each player gets a column. Compare progress vertically.</N>
    <N top={500} left={-140} width={130}>Input panel at bottom: 7 number buttons + S/D/T.</N>
  </div>
);

/* ──────────────────────────────────────────────────────────
   4. PLAYER SETUP — A revisited + randomize
   ────────────────────────────────────────────────────────── */
const Setupv3 = () => (
  <DCSection id="setup-v3" title="Player setup · grid with order, plus randomize">
    <DCArtboard id="setup-pick" label="Setup with randomize" width={540} height={720}><SetupGrid/></DCArtboard>
  </DCSection>
);

const playersData3 = [
  {n:'Andreas', c:'#FFB300', sel:1},
  {n:'Jonas',   c:'#FF6B35', sel:2},
  {n:'Mia',     c:'#4F5DC4', sel:3},
  {n:'Erik',    c:'#815668', sel:0},
  {n:'Lars',    c:'#66BB6A', sel:0},
  {n:'Kari',    c:'#9C27B0', sel:0},
  {n:'Tor',     c:'#00ACC1', sel:0},
  {n:'Ida',     c:'#E91E63', sel:0},
  {n:'Even',    c:'#5D4037', sel:0},
];

const SetupGrid = () => (
  <div className="tab3 d1">
    <div className="dot"/>
    <div className="broadcast">
      <div style={{padding:'8px 14px', fontFamily:'var(--mono)', fontWeight:800}}>← BACK</div>
      <div className="meta" style={{textAlign:'center'}}>NEW GAME</div>
      <div style={{padding:'8px 14px'}}>⚙</div>
    </div>

    {/* Game settings strip */}
    <div style={{padding:'10px 14px', borderBottom:'1px solid var(--d1-line)', display:'flex', gap:8, alignItems:'center', flexWrap:'wrap'}}>
      <div className="label-tiny">MODE</div>
      <div style={{padding:'4px 12px', background:'var(--d1-energy)', color:'#000', borderRadius:6, fontFamily:'var(--display)', fontSize:14}}>X01</div>
      <div className="label-tiny" style={{marginLeft:8}}>START</div>
      <div style={{display:'flex', gap:4}}>
        <div style={{padding:'4px 10px', background:'var(--d1-bg-2)', borderRadius:6, fontFamily:'var(--mono)', fontSize:11}}>301</div>
        <div style={{padding:'4px 10px', background:'var(--d1-energy)', color:'#000', borderRadius:6, fontFamily:'var(--mono)', fontSize:11, fontWeight:800}}>501</div>
        <div style={{padding:'4px 10px', background:'var(--d1-bg-2)', borderRadius:6, fontFamily:'var(--mono)', fontSize:11}}>701</div>
      </div>
      <div style={{flex:1}}/>
      <div style={{padding:'4px 8px', background:'var(--d1-bg-2)', borderRadius:6, fontSize:10, fontFamily:'var(--mono)', letterSpacing:1}}>D-OUT</div>
    </div>

    {/* Sticky header: counter + RANDOMIZE button */}
    <div style={{padding:'10px 14px', borderBottom:'1px solid var(--d1-line)', display:'flex', alignItems:'center', gap:10, background:'var(--d1-bg-1)'}}>
      <div style={{padding:'6px 12px', background:'var(--d1-energy-2)', color:'#fff', borderRadius:100, fontFamily:'var(--mono)', fontSize:11, fontWeight:800, letterSpacing:1}}>
        3 SELECTED
      </div>
      <div style={{flex:1}}/>
      <div style={{padding:'6px 12px', background:'var(--d1-bg-2)', color:'var(--d1-text)', borderRadius:100, fontSize:11, fontFamily:'var(--mono)', fontWeight:700, letterSpacing:1, display:'inline-flex', gap:6, alignItems:'center', border:'1px solid var(--d1-chrome)'}}>
        <span style={{fontSize:13}}>🎲</span> RANDOMIZE ORDER
      </div>
    </div>

    {/* Grid of player tiles */}
    <div style={{padding:14, flex:1, overflow:'hidden'}}>
      <div style={{display:'grid', gridTemplateColumns:'repeat(3, 1fr)', gap:10}}>
        {playersData3.map(p => {
          const sel = p.sel > 0;
          return (
            <div key={p.n} style={{
              aspectRatio:'1/1',
              background: sel ? 'var(--d1-bg-2)' : 'var(--d1-bg-1)',
              border: '1.5px solid ' + (sel ? 'var(--d1-energy)' : 'var(--d1-line)'),
              borderRadius:12,
              padding:8,
              display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:4,
              position:'relative',
            }}>
              {sel && (
                <div style={{
                  position:'absolute', top:6, right:6,
                  width:24, height:24, borderRadius:'50%',
                  background:'var(--d1-energy)', color:'#000',
                  display:'flex', alignItems:'center', justifyContent:'center',
                  fontFamily:'var(--display)', fontSize:14,
                }}>{p.sel}</div>
              )}
              <div className="av3 md" style={{background:p.c, color:'#000'}}>{p.n[0]}</div>
              <div style={{fontSize:11, fontWeight:600}}>{p.n}</div>
              <div className="label-tiny" style={{fontSize:9}}>1{Math.floor(Math.random()*5)}{Math.floor(Math.random()*9)}{Math.floor(Math.random()*9)}</div>
            </div>
          );
        })}
      </div>
    </div>

    <div style={{padding:'10px 14px', display:'flex', gap:8, alignItems:'center', borderTop:'1px solid var(--d1-line)'}}>
      <div className="btn3 outline">+ NEW</div>
      <div className="btn3 ghost">CLEAR</div>
      <div style={{flex:1}}/>
      <div className="btn3 primary">START →</div>
    </div>

    <N top={170} right={-160} width={160}><strong>🎲 Randomize</strong> button you asked for — shuffles selected players' throw order. Animation could roll the order chips.</N>
    <N top={300} left={-140} width={130}>Numeric badge in the corner = throw position. Long-press to reorder.</N>
  </div>
);

/* ──────────────────────────────────────────────────────────
   5. POST-GAME — A reverted + matrix reinstated
   ────────────────────────────────────────────────────────── */
const PostGamev3 = () => (
  <DCSection id="postgame-v3" title="Post-game · A reverted, matrix re-added, rematch primary">
    <DCArtboard id="pg-stadium" label="Stadium recap with matrix" width={540} height={720}><PgStadium/></DCArtboard>
  </DCSection>
);

const PgStadium = () => (
  <div className="tab3 d1">
    <div className="dot"/>
    {/* Top broadcast strip */}
    <div className="broadcast">
      <div className="live" style={{background:'var(--d1-energy)', color:'#000'}}>FINAL</div>
      <div className="meta">501 · DOUBLE-OUT · 2:14</div>
      <div style={{padding:'8px 14px'}}>⚙</div>
    </div>

    {/* Winner block — full bleed */}
    <div className="now-throw" style={{padding:'18px 20px'}}>
      <div className="label-tiny">WINNER</div>
      <div style={{display:'flex', alignItems:'center', gap:14, marginTop:6}}>
        <div className="av3 lg energy" style={{width:60, height:60, fontSize:24}}>A</div>
        <div style={{flex:1}}>
          <div style={{fontFamily:'var(--display)', fontSize:38, lineHeight:0.9}}>ANDREAS</div>
          <div style={{display:'inline-flex', gap:8, marginTop:6, padding:'2px 10px', background:'rgba(255,179,0,0.15)', borderRadius:100}}>
            <span className="label-tiny" style={{color:'var(--d1-energy)'}}>RATING</span>
            <span style={{fontFamily:'var(--mono)', fontSize:11, fontWeight:700}}>1450 → 1474</span>
            <span style={{fontFamily:'var(--mono)', fontSize:11, fontWeight:800, color:'var(--d1-energy)'}}>+24</span>
          </div>
        </div>
        <div style={{textAlign:'right'}}>
          <div className="label-tiny">DARTS</div>
          <div style={{fontFamily:'var(--display)', fontSize:46, lineHeight:0.9, color:'var(--d1-energy)'}}>18</div>
        </div>
      </div>
    </div>

    {/* THE MATRIX — comparison table */}
    <div style={{padding:'12px 14px 8px'}}>
      <div className="label-tiny" style={{marginBottom:6}}>HOW IT WENT DOWN</div>
      <div className="stat-matrix" style={{gridTemplateColumns:'1.4fr 0.7fr 0.7fr 0.7fr 0.7fr'}}>
        <div className="h first">PLAYER</div>
        <div className="h">BEST</div>
        <div className="h">AVG</div>
        <div className="h">DARTS</div>
        <div className="h">Δ</div>

        <div className="c name">
          <div className="av3 sm" style={{background:'var(--d1-energy)', color:'#000'}}>A</div>
          <span style={{fontWeight:800}}>Andreas</span>
        </div>
        <div className="c best">140</div>
        <div className="c">78.4</div>
        <div className="c best">18</div>
        <div className="c best">+24</div>

        <div className="c name">
          <div className="av3 sm" style={{background:'var(--d1-energy-2)'}}>J</div>
          <span>Jonas</span>
        </div>
        <div className="c">100</div>
        <div className="c">62.1</div>
        <div className="c">24</div>
        <div className="c" style={{color:'#66BB6A'}}>+5</div>

        <div className="c name">
          <div className="av3 sm" style={{background:'var(--d1-chrome)'}}>M</div>
          <span>Mia</span>
        </div>
        <div className="c">80</div>
        <div className="c">51.0</div>
        <div className="c">24</div>
        <div className="c" style={{color:'var(--d1-energy-2)'}}>−12</div>
      </div>
    </div>

    {/* Score progression chart — small, secondary */}
    <div style={{padding:'4px 14px 8px'}}>
      <div className="label-tiny" style={{marginBottom:4}}>SCORE PROGRESSION · ROUNDS 1–8</div>
      <svg viewBox="0 0 480 100" style={{width:'100%', height:90, display:'block'}}>
        {[0,125,250,375,500].map(v=>(
          <line key={v} x1="0" x2="480" y1={100 - (v/501)*100} y2={100 - (v/501)*100} stroke="var(--d1-line)" strokeWidth="0.5" strokeDasharray="2 4"/>
        ))}
        {[
          {c:'var(--d1-energy)', pts:[501,441,381,321,261,201,121,61,0]},
          {c:'var(--d1-energy-2)', pts:[501,461,421,381,341,301,261,221,180]},
          {c:'var(--d1-chrome)', pts:[501,481,461,441,421,401,381,361,341]},
        ].map((p,i)=>(
          <polyline key={i} points={p.pts.map((y,x)=>`${x*60},${100-(y/501)*100}`).join(' ')} fill="none" stroke={p.c} strokeWidth="2" strokeLinejoin="round"/>
        ))}
        <circle cx="480" cy="100" r="4" fill="var(--d1-energy)" stroke="var(--d1-bg)" strokeWidth="2"/>
      </svg>
    </div>

    {/* Highlights — reels */}
    <div style={{padding:'4px 14px 8px', flex:1}}>
      <div className="label-tiny" style={{marginBottom:6}}>HIGHLIGHTS</div>
      <div style={{display:'flex', flexDirection:'column', gap:4, fontSize:11}}>
        <div>● R4 — Andreas posts <strong style={{color:'var(--d1-energy)'}}>140</strong> (T20·T20·D10) · personal best</div>
        <div>● R6 — Jonas busts on 36</div>
        <div>● R8 — Checkout <strong style={{color:'var(--d1-energy)'}}>T20·D20</strong> takes the leg</div>
      </div>
    </div>

    {/* Footer — REMATCH primary */}
    <div style={{padding:'10px 12px', display:'flex', gap:8, borderTop:'1px solid var(--d1-line)'}}>
      <div className="btn3 ghost">HOME</div>
      <div className="btn3 outline">↶ UNDO LAST</div>
      <div style={{flex:1}}/>
      <div className="btn3 primary">REMATCH →</div>
    </div>

    <N top={210} right={-160} width={160}>Stadium feel from v1 A. Winner card + DARTS hero.</N>
    <N top={350} left={-150} width={140}><strong>The matrix is back</strong> — best/avg/darts/Δ side-by-side.</N>
    <N top={620} right={-150} width={140}>REMATCH is primary. Your weekend pub-night CTA.</N>
  </div>
);

/* ──────────────────────────────────────────────────────────
   6. STATS PAGE — new, three takes
   ────────────────────────────────────────────────────────── */
const Statsv3 = () => (
  <DCSection id="stats-v3" title="Stats page · designing this from scratch">
    <DCArtboard id="stats-overview" label="A · Career overview" width={540} height={720}><StatsOverview/></DCArtboard>
    <DCArtboard id="stats-leader"   label="B · Leaderboard + filters" width={540} height={720}><StatsLeaderboard/></DCArtboard>
    <DCArtboard id="stats-h2h"      label="C · Head-to-head" width={540} height={720}><StatsH2H/></DCArtboard>
  </DCSection>
);

const StatsOverview = () => (
  <div className="tab3 d1">
    <div className="dot"/>
    <div className="broadcast">
      <div style={{padding:'8px 14px', fontFamily:'var(--mono)', fontWeight:800}}>← HOME</div>
      <div className="meta">STATS · ANDREAS</div>
      <div style={{padding:'8px 14px'}}>👤</div>
    </div>

    {/* Hero rating */}
    <div style={{padding:'18px 20px', display:'flex', alignItems:'center', gap:14, borderBottom:'1px solid var(--d1-line)', background:'linear-gradient(180deg, rgba(255,179,0,0.08), transparent)'}}>
      <div className="av3 lg energy" style={{width:64, height:64, fontSize:26}}>A</div>
      <div style={{flex:1}}>
        <div className="label-tiny">RATING · #2 OF 9</div>
        <div style={{fontFamily:'var(--display)', fontSize:48, lineHeight:0.9, color:'var(--d1-energy)'}}>1474</div>
        <div style={{fontFamily:'var(--mono)', fontSize:10, color:'var(--d1-text-v)', marginTop:4}}>+47 last 30 days · best 1502</div>
      </div>
      {/* Rating sparkline */}
      <svg width="80" height="50" viewBox="0 0 80 50">
        <polyline points="0,40 10,38 20,32 30,35 40,30 50,22 60,25 70,15 80,10" fill="none" stroke="var(--d1-energy)" strokeWidth="2"/>
      </svg>
    </div>

    {/* KPI tiles */}
    <div style={{padding:'12px 14px', display:'grid', gridTemplateColumns:'repeat(3, 1fr)', gap:8}}>
      {[
        {l:'GAMES', v:'47', s:'33W · 14L'},
        {l:'WIN %', v:'70', s:'last 10: 8W'},
        {l:'BEST',  v:'180', s:'27 Aug'},
        {l:'AVG',   v:'62.4', s:'all modes'},
        {l:'180s',  v:'4', s:'this year'},
        {l:'CHKO',  v:'D20', s:'favorite'},
      ].map(k=>(
        <div key={k.l} style={{
          padding:'10px 12px',
          background:'var(--d1-bg-1)',
          border:'1px solid var(--d1-line)',
          borderRadius:10,
        }}>
          <div className="label-tiny">{k.l}</div>
          <div style={{fontFamily:'var(--display)', fontSize:28, lineHeight:1, marginTop:4, color: ['180','BEST'].includes(k.l)?'var(--d1-energy)':'var(--d1-text)'}}>{k.v}</div>
          <div style={{fontFamily:'var(--mono)', fontSize:9, color:'var(--d1-text-v)', marginTop:4}}>{k.s}</div>
        </div>
      ))}
    </div>

    {/* Mode breakdown */}
    <div style={{padding:'4px 14px 12px'}}>
      <div className="label-tiny" style={{marginBottom:6}}>BY MODE</div>
      <div className="stat-matrix" style={{gridTemplateColumns:'1fr 0.6fr 0.6fr 0.6fr'}}>
        <div className="h first">MODE</div><div className="h">GAMES</div><div className="h">WIN%</div><div className="h">AVG</div>
        <div className="c name"><span>501 D-out</span></div><div className="c">28</div><div className="c best">75</div><div className="c">68.2</div>
        <div className="c name"><span>301 D-out</span></div><div className="c">12</div><div className="c">58</div><div className="c">52.0</div>
        <div className="c name"><span>Cricket</span></div><div className="c">7</div><div className="c">71</div><div className="c">—</div>
      </div>
    </div>

    {/* Recent games strip */}
    <div style={{padding:'4px 14px 8px', flex:1}}>
      <div className="label-tiny" style={{marginBottom:6}}>RECENT</div>
      <div style={{display:'flex', flexDirection:'column', gap:4}}>
        {[
          {r:'W', mode:'501 D-out', vs:'Jonas, Mia', d:'2h ago', delta:'+24'},
          {r:'W', mode:'Cricket',   vs:'Erik',        d:'yesterday', delta:'+12'},
          {r:'L', mode:'501 D-out', vs:'Mia',         d:'2 days',    delta:'−18'},
          {r:'W', mode:'301 D-out', vs:'Lars, Jonas', d:'3 days',    delta:'+9'},
        ].map((g,i)=>(
          <div key={i} style={{display:'flex', alignItems:'center', gap:8, padding:'6px 10px', background:'var(--d1-bg-1)', borderRadius:8, fontSize:11}}>
            <div style={{
              width:22, height:22, borderRadius:5,
              background: g.r==='W'?'var(--d1-energy)':'var(--d1-bg-3)',
              color: g.r==='W'?'#000':'var(--d1-text-v)',
              display:'flex', alignItems:'center', justifyContent:'center',
              fontFamily:'var(--display)', fontSize:13,
            }}>{g.r}</div>
            <div style={{flex:1}}>
              <div style={{fontWeight:700}}>{g.mode}</div>
              <div className="label-tiny" style={{fontSize:9}}>vs {g.vs} · {g.d}</div>
            </div>
            <div style={{fontFamily:'var(--mono)', fontSize:11, fontWeight:800, color: g.delta.startsWith('+')?'#66BB6A':'var(--d1-energy-2)'}}>{g.delta}</div>
          </div>
        ))}
      </div>
    </div>

    {/* Bottom: tab nav (you said "next to settings on the homepage") */}
    <div style={{display:'flex', borderTop:'1px solid var(--d1-line)', background:'var(--d1-bg-1)'}}>
      {['OVERVIEW','LEADERBOARD','H2H'].map((t,i)=>(
        <div key={t} style={{
          flex:1, padding:'12px 0', textAlign:'center',
          fontFamily:'var(--mono)', fontSize:10, letterSpacing:1.5, fontWeight:800,
          color: i===0 ? 'var(--d1-energy)' : 'var(--d1-text-v)',
          borderTop: i===0 ? '2px solid var(--d1-energy)' : 'none',
        }}>{t}</div>
      ))}
    </div>

    <N top={140} right={-150} width={140}>Hero rating + sparkline. Three sub-tabs at the bottom.</N>
    <N top={290} left={-150} width={140}>KPI grid: 6 numbers any pub regular wants to know about themselves.</N>
  </div>
);

const StatsLeaderboard = () => (
  <div className="tab3 d1">
    <div className="dot"/>
    <div className="broadcast">
      <div style={{padding:'8px 14px', fontFamily:'var(--mono)', fontWeight:800}}>← HOME</div>
      <div className="meta">LEADERBOARD</div>
      <div style={{padding:'8px 14px'}}>⚙</div>
    </div>

    {/* Filters */}
    <div style={{padding:'10px 14px', borderBottom:'1px solid var(--d1-line)', display:'flex', gap:6, alignItems:'center', flexWrap:'wrap'}}>
      <div className="label-tiny">SORT BY</div>
      <div style={{padding:'4px 10px', background:'var(--d1-energy)', color:'#000', borderRadius:6, fontFamily:'var(--mono)', fontSize:10, fontWeight:800}}>RATING</div>
      <div style={{padding:'4px 10px', background:'var(--d1-bg-2)', borderRadius:6, fontFamily:'var(--mono)', fontSize:10}}>WIN%</div>
      <div style={{padding:'4px 10px', background:'var(--d1-bg-2)', borderRadius:6, fontFamily:'var(--mono)', fontSize:10}}>AVG</div>
      <div style={{padding:'4px 10px', background:'var(--d1-bg-2)', borderRadius:6, fontFamily:'var(--mono)', fontSize:10}}>180s</div>
      <div style={{flex:1}}/>
      <div style={{padding:'4px 10px', background:'var(--d1-bg-2)', borderRadius:6, fontFamily:'var(--mono)', fontSize:10}}>ALL MODES ▾</div>
    </div>

    {/* Podium for top 3 */}
    <div style={{padding:'18px 20px 10px', display:'flex', alignItems:'flex-end', justifyContent:'center', gap:10}}>
      {[
        {p:2, n:'Mia',     r:1502, h:90, c:'var(--d1-chrome)'},
        {p:1, n:'Jonas',   r:1518, h:120, c:'var(--d1-energy)'},
        {p:3, n:'Andreas', r:1474, h:70, c:'var(--d1-energy-2)'},
      ].map(x=>(
        <div key={x.p} style={{flex:1, textAlign:'center'}}>
          <div className="av3 md" style={{margin:'0 auto 6px', background:x.c, color:'#000'}}>{x.n[0]}</div>
          <div style={{fontSize:11, fontWeight:700}}>{x.n}</div>
          <div style={{fontFamily:'var(--mono)', fontSize:10, color:'var(--d1-text-v)'}}>{x.r}</div>
          <div style={{
            marginTop:6, height:x.h,
            background:x.c, borderRadius:'4px 4px 0 0',
            display:'flex', alignItems:'flex-start', justifyContent:'center', paddingTop:8,
            color:'#000', fontFamily:'var(--display)', fontSize:24,
          }}>{x.p}</div>
        </div>
      ))}
    </div>

    {/* Rest of the table */}
    <div style={{padding:'4px 14px 8px', flex:1}}>
      <div className="stat-matrix" style={{gridTemplateColumns:'30px 1fr 0.6fr 0.6fr 0.6fr'}}>
        <div className="h first">#</div><div className="h first">PLAYER</div><div className="h">RATING</div><div className="h">W/L</div><div className="h">AVG</div>
        {[
          {r:4, n:'Erik',  rt:1421, wl:'21/14', a:58.2},
          {r:5, n:'Lars',  rt:1408, wl:'18/19', a:54.1},
          {r:6, n:'Kari',  rt:1392, wl:'15/12', a:55.3},
          {r:7, n:'Tor',   rt:1380, wl:'12/16', a:50.0},
          {r:8, n:'Ida',   rt:1361, wl:'10/14', a:48.7},
          {r:9, n:'Even',  rt:1340, wl:'8/13',  a:46.2},
        ].map(x=>(
          <React.Fragment key={x.n}>
            <div className="c">{x.r}</div>
            <div className="c name">
              <div className="av3 sm" style={{background:'var(--d1-bg-3)'}}>{x.n[0]}</div>
              <span>{x.n}</span>
            </div>
            <div className="c">{x.rt}</div>
            <div className="c">{x.wl}</div>
            <div className="c">{x.a}</div>
          </React.Fragment>
        ))}
      </div>
    </div>

    <div style={{display:'flex', borderTop:'1px solid var(--d1-line)', background:'var(--d1-bg-1)'}}>
      {['OVERVIEW','LEADERBOARD','H2H'].map((t,i)=>(
        <div key={t} style={{
          flex:1, padding:'12px 0', textAlign:'center',
          fontFamily:'var(--mono)', fontSize:10, letterSpacing:1.5, fontWeight:800,
          color: i===1 ? 'var(--d1-energy)' : 'var(--d1-text-v)',
          borderTop: i===1 ? '2px solid var(--d1-energy)' : 'none',
        }}>{t}</div>
      ))}
    </div>

    <N top={130} right={-150} width={140}>Filter chips for sort + mode. Top 3 podium. Long-tail in matrix.</N>
  </div>
);

const StatsH2H = () => (
  <div className="tab3 d1">
    <div className="dot"/>
    <div className="broadcast">
      <div style={{padding:'8px 14px', fontFamily:'var(--mono)', fontWeight:800}}>← HOME</div>
      <div className="meta">HEAD-TO-HEAD</div>
      <div style={{padding:'8px 14px'}}>⚙</div>
    </div>

    {/* VS header */}
    <div style={{padding:'18px 20px', display:'flex', alignItems:'center', gap:8, borderBottom:'1px solid var(--d1-line)'}}>
      <div style={{flex:1, textAlign:'center'}}>
        <div className="av3" style={{width:56, height:56, fontSize:22, background:'var(--d1-energy)', color:'#000', margin:'0 auto'}}>A</div>
        <div style={{fontFamily:'var(--display)', fontSize:20, marginTop:6}}>ANDREAS</div>
        <div style={{fontFamily:'var(--mono)', fontSize:10, color:'var(--d1-text-v)'}}>1474</div>
      </div>
      <div style={{fontFamily:'var(--display)', fontSize:30, color:'var(--d1-energy-2)'}}>VS</div>
      <div style={{flex:1, textAlign:'center'}}>
        <div className="av3" style={{width:56, height:56, fontSize:22, background:'var(--d1-chrome)', color:'#fff', margin:'0 auto'}}>M</div>
        <div style={{fontFamily:'var(--display)', fontSize:20, marginTop:6}}>MIA</div>
        <div style={{fontFamily:'var(--mono)', fontSize:10, color:'var(--d1-text-v)'}}>1502</div>
      </div>
    </div>

    {/* Diverging bar — record */}
    <div style={{padding:'14px 18px'}}>
      <div className="label-tiny" style={{marginBottom:6}}>RECORD · 12 GAMES</div>
      <div style={{display:'flex', height:32, borderRadius:8, overflow:'hidden', border:'1px solid var(--d1-line)'}}>
        <div style={{flex:'7 0 0', background:'var(--d1-energy)', color:'#000', display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'var(--display)', fontSize:18}}>7W</div>
        <div style={{flex:'5 0 0', background:'var(--d1-chrome)', color:'#fff', display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'var(--display)', fontSize:18}}>5</div>
      </div>
      <div style={{fontSize:11, fontFamily:'var(--mono)', textAlign:'center', marginTop:6, color:'var(--d1-text-v)'}}>
        Andreas leads 7–5 · last meeting won by <span style={{color:'var(--d1-energy)'}}>ANDREAS</span>
      </div>
    </div>

    {/* Side-by-side stats */}
    <div style={{padding:'4px 14px'}}>
      <div className="label-tiny" style={{marginBottom:6}}>HEAD TO HEAD</div>
      <div className="stat-matrix" style={{gridTemplateColumns:'0.7fr 1fr 0.7fr'}}>
        <div className="h" style={{textAlign:'right'}}>ANDREAS</div>
        <div className="h first" style={{textAlign:'center'}}>STAT</div>
        <div className="h" style={{textAlign:'left'}}>MIA</div>
        {[
          {a:'62.4', s:'AVG', m:'58.1', who:'A'},
          {a:'140',  s:'BEST', m:'120', who:'A'},
          {a:'4',    s:'180s', m:'2', who:'A'},
          {a:'18',   s:'BEST CHKO', m:'21', who:'A'},
          {a:'15',   s:'CHKO %', m:'22', who:'M'},
          {a:'D20',  s:'FAV', m:'D16', who:'-'},
        ].map((row,i)=>(
          <React.Fragment key={i}>
            <div className="c" style={{textAlign:'right', color: row.who==='A' ? 'var(--d1-energy)' : 'var(--d1-text)'}}>{row.a}</div>
            <div className="c" style={{textAlign:'center', color:'var(--d1-text-v)', fontWeight:500}}>{row.s}</div>
            <div className="c" style={{textAlign:'left', color: row.who==='M' ? 'var(--d1-energy)' : 'var(--d1-text)'}}>{row.m}</div>
          </React.Fragment>
        ))}
      </div>
    </div>

    {/* Recent meetings */}
    <div style={{padding:'10px 14px', flex:1}}>
      <div className="label-tiny" style={{marginBottom:6}}>RECENT MEETINGS</div>
      <div style={{display:'flex', flexDirection:'column', gap:4}}>
        {[
          {w:'A', mode:'501', d:'2h',     score:'18 darts'},
          {w:'A', mode:'301', d:'5 days', score:'12 darts'},
          {w:'M', mode:'Cri', d:'1 wk',   score:'closed all'},
          {w:'A', mode:'501', d:'2 wks',  score:'21 darts'},
        ].map((g,i)=>(
          <div key={i} style={{display:'flex', alignItems:'center', gap:8, padding:'6px 10px', background:'var(--d1-bg-1)', borderRadius:6, fontSize:11}}>
            <div style={{
              width:20, height:20, borderRadius:4,
              background: g.w==='A'?'var(--d1-energy)':'var(--d1-chrome)',
              color: g.w==='A'?'#000':'#fff',
              display:'flex', alignItems:'center', justifyContent:'center',
              fontFamily:'var(--display)', fontSize:11,
            }}>{g.w}</div>
            <span style={{flex:1, fontFamily:'var(--mono)'}}>{g.mode} · {g.d} ago</span>
            <span style={{fontFamily:'var(--mono)', color:'var(--d1-text-v)'}}>{g.score}</span>
          </div>
        ))}
      </div>
    </div>

    <div style={{display:'flex', borderTop:'1px solid var(--d1-line)', background:'var(--d1-bg-1)'}}>
      {['OVERVIEW','LEADERBOARD','H2H'].map((t,i)=>(
        <div key={t} style={{
          flex:1, padding:'12px 0', textAlign:'center',
          fontFamily:'var(--mono)', fontSize:10, letterSpacing:1.5, fontWeight:800,
          color: i===2 ? 'var(--d1-energy)' : 'var(--d1-text-v)',
          borderTop: i===2 ? '2px solid var(--d1-energy)' : 'none',
        }}>{t}</div>
      ))}
    </div>

    <N top={170} right={-150} width={140}>Diverging bar = the rivalry story at a glance.</N>
    <N top={350} left={-140} width={130}>Three columns: my stat / label / their stat. Winner highlighted per row.</N>
  </div>
);

window.ColorCompare = ColorCompare;
window.X01v3 = X01v3;
window.Cricketv3 = Cricketv3;
window.Setupv3 = Setupv3;
window.PostGamev3 = PostGamev3;
window.Statsv3 = Statsv3;
