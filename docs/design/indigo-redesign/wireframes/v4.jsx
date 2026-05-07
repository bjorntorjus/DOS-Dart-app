// v4 — narrow scope: indigo only, X01 + setup + postgame, cricket recolor stub

const N = ({ top, left, right, width = 160, children }) => (
  <div className="note3" style={{ top, left, right, width }}>{children}</div>
);

/* X01 — v1 stadium + player strip + UNDO + BACK */
const X01v4 = () => (
  <DCSection id="x01-v4" title="X01 in-game · final · indigo + amber">
    <DCArtboard id="x01-final" label="X01 stadium" width={540} height={720}><X01Final/></DCArtboard>
  </DCSection>
);

const X01Final = () => (
  <div className="tab3 d1">
    <div className="dot"/>
    {/* Top: BACK + meta + settings */}
    <div className="broadcast">
      <div style={{padding:'8px 12px', fontFamily:'var(--mono)', fontSize:11, fontWeight:800, color:'var(--d1-text-v)', borderRight:'1px solid var(--d1-line)', cursor:'pointer'}}>← BACK</div>
      <div style={{padding:'8px 14px', background:'var(--d1-energy-2)', color:'#fff', fontFamily:'var(--mono)', fontSize:10, fontWeight:800, letterSpacing:2}}>LIVE</div>
      <div className="meta">501 · D-OUT · R7 · LEG 1</div>
      <div style={{padding:'8px 14px'}}>⚙</div>
    </div>

    {/* NOW THROWING */}
    <div className="now-throw">
      <div className="label-tiny">NOW THROWING</div>
      <div style={{display:'flex', alignItems:'center', gap:14, marginTop:6}}>
        <div className="av3 lg energy">A</div>
        <div style={{flex:1}}>
          <div style={{fontFamily:'var(--display)', fontSize:30, lineHeight:0.9}}>ANDREAS</div>
          <div style={{display:'flex', gap:6, marginTop:8, alignItems:'center'}}>
            {[1,2,3].map(i => (
              <div key={i} style={{width:32, height:6, borderRadius:3, background:i<=2?'var(--d1-energy-2)':'rgba(255,255,255,0.1)'}}/>
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
        <div style={{color:'var(--d1-energy)', fontWeight:800, fontFamily:'var(--mono)'}}>↪ T20·D20</div>
      </div>
    </div>

    {/* Other players strip */}
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

    {/* Footer with UNDO + MISS + END TURN */}
    <div style={{padding:'10px 12px', display:'flex', gap:8, alignItems:'center', borderTop:'1px solid var(--d1-line)'}}>
      <div className="btn3 outline" style={{padding:'12px 16px'}}>↶ UNDO</div>
      <div className="btn3 ghost">MISS</div>
      <div style={{flex:1}}/>
      <div className="btn3 primary">END TURN</div>
    </div>

    <N top={50} left={-150} width={140}>← BACK in top-left as a tappable cell.</N>
    <N top={620} left={-150} width={140}>↶ UNDO is now first in the footer — most-used after MISS.</N>
  </div>
);

/* SETUP — grid + randomize */
const Setupv4 = () => (
  <DCSection id="setup-v4" title="Player setup · indigo + randomize">
    <DCArtboard id="setup-final" label="Setup" width={540} height={720}><SetupFinal/></DCArtboard>
  </DCSection>
);

const playersData4 = [
  {n:'Andreas', c:'#FFB300', sel:1}, {n:'Jonas', c:'#FF6B35', sel:2}, {n:'Mia', c:'#4F5DC4', sel:3},
  {n:'Erik', c:'#815668', sel:0}, {n:'Lars', c:'#66BB6A', sel:0}, {n:'Kari', c:'#9C27B0', sel:0},
  {n:'Tor', c:'#00ACC1', sel:0}, {n:'Ida', c:'#E91E63', sel:0}, {n:'Even', c:'#5D4037', sel:0},
];

const SetupFinal = () => (
  <div className="tab3 d1">
    <div className="dot"/>
    <div className="broadcast">
      <div style={{padding:'8px 12px', fontFamily:'var(--mono)', fontWeight:800}}>← BACK</div>
      <div className="meta" style={{textAlign:'center'}}>NEW GAME</div>
      <div style={{padding:'8px 14px'}}>⚙</div>
    </div>

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

    <div style={{padding:'10px 14px', borderBottom:'1px solid var(--d1-line)', display:'flex', alignItems:'center', gap:10, background:'var(--d1-bg-1)'}}>
      <div style={{padding:'6px 12px', background:'var(--d1-energy-2)', color:'#fff', borderRadius:100, fontFamily:'var(--mono)', fontSize:11, fontWeight:800, letterSpacing:1}}>3 SELECTED</div>
      <div style={{flex:1}}/>
      <div style={{padding:'6px 12px', background:'var(--d1-bg-2)', color:'var(--d1-text)', borderRadius:100, fontSize:11, fontFamily:'var(--mono)', fontWeight:700, letterSpacing:1, display:'inline-flex', gap:6, alignItems:'center', border:'1px solid var(--d1-chrome)'}}>
        <span style={{fontSize:13}}>🎲</span> RANDOMIZE
      </div>
    </div>

    <div style={{padding:14, flex:1, overflow:'hidden'}}>
      <div style={{display:'grid', gridTemplateColumns:'repeat(3, 1fr)', gap:10}}>
        {playersData4.map(p => {
          const sel = p.sel > 0;
          return (
            <div key={p.n} style={{
              aspectRatio:'1/1',
              background: sel ? 'var(--d1-bg-2)' : 'var(--d1-bg-1)',
              border: '1.5px solid ' + (sel ? 'var(--d1-energy)' : 'var(--d1-line)'),
              borderRadius:12, padding:8, position:'relative',
              display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:4,
            }}>
              {sel && (
                <div style={{
                  position:'absolute', top:6, right:6, width:24, height:24, borderRadius:'50%',
                  background:'var(--d1-energy)', color:'#000',
                  display:'flex', alignItems:'center', justifyContent:'center',
                  fontFamily:'var(--display)', fontSize:14,
                }}>{p.sel}</div>
              )}
              <div className="av3 md" style={{background:p.c, color:'#000'}}>{p.n[0]}</div>
              <div style={{fontSize:11, fontWeight:600}}>{p.n}</div>
            </div>
          );
        })}
      </div>
    </div>

    <div style={{padding:'10px 14px', display:'flex', gap:8, borderTop:'1px solid var(--d1-line)'}}>
      <div className="btn3 outline">+ NEW</div>
      <div className="btn3 ghost">CLEAR</div>
      <div style={{flex:1}}/>
      <div className="btn3 primary">START →</div>
    </div>
  </div>
);

/* POST-GAME — stadium + matrix */
const PostGamev4 = () => (
  <DCSection id="postgame-v4" title="Post-game · stadium + matrix">
    <DCArtboard id="pg-final" label="Game over" width={540} height={720}><PgFinal/></DCArtboard>
  </DCSection>
);

const PgFinal = () => (
  <div className="tab3 d1">
    <div className="dot"/>
    <div className="broadcast">
      <div className="live" style={{background:'var(--d1-energy)', color:'#000'}}>FINAL</div>
      <div className="meta">501 · DOUBLE-OUT · 2:14</div>
      <div style={{padding:'8px 14px'}}>⚙</div>
    </div>

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

    <div style={{padding:'12px 14px 8px'}}>
      <div className="label-tiny" style={{marginBottom:6}}>HOW IT WENT DOWN</div>
      <div className="stat-matrix" style={{gridTemplateColumns:'1.4fr 0.7fr 0.7fr 0.7fr 0.7fr'}}>
        <div className="h first">PLAYER</div><div className="h">BEST</div><div className="h">AVG</div><div className="h">DARTS</div><div className="h">Δ</div>
        <div className="c name"><div className="av3 sm" style={{background:'var(--d1-energy)', color:'#000'}}>A</div><span style={{fontWeight:800}}>Andreas</span></div>
        <div className="c best">140</div><div className="c">78.4</div><div className="c best">18</div><div className="c best">+24</div>
        <div className="c name"><div className="av3 sm" style={{background:'var(--d1-energy-2)'}}>J</div><span>Jonas</span></div>
        <div className="c">100</div><div className="c">62.1</div><div className="c">24</div><div className="c" style={{color:'#66BB6A'}}>+5</div>
        <div className="c name"><div className="av3 sm" style={{background:'var(--d1-chrome)'}}>M</div><span>Mia</span></div>
        <div className="c">80</div><div className="c">51.0</div><div className="c">24</div><div className="c" style={{color:'var(--d1-energy-2)'}}>−12</div>
      </div>
    </div>

    <div style={{padding:'4px 14px 8px'}}>
      <div className="label-tiny" style={{marginBottom:4}}>SCORE PROGRESSION</div>
      <svg viewBox="0 0 480 100" style={{width:'100%', height:90, display:'block'}}>
        {[0,125,250,375,500].map(v=>(
          <line key={v} x1="0" x2="480" y1={100 - (v/501)*100} y2={100 - (v/501)*100} stroke="var(--d1-line)" strokeWidth="0.5" strokeDasharray="2 4"/>
        ))}
        {[
          {c:'var(--d1-energy)', pts:[501,441,381,321,261,201,121,61,0]},
          {c:'var(--d1-energy-2)', pts:[501,461,421,381,341,301,261,221,180]},
          {c:'var(--d1-chrome)', pts:[501,481,461,441,421,401,381,361,341]},
        ].map((p,i)=>(
          <polyline key={i} points={p.pts.map((y,x)=>`${x*60},${100-(y/501)*100}`).join(' ')} fill="none" stroke={p.c} strokeWidth="2"/>
        ))}
      </svg>
    </div>

    <div style={{padding:'4px 14px 8px', flex:1}}>
      <div className="label-tiny" style={{marginBottom:6}}>HIGHLIGHTS</div>
      <div style={{display:'flex', flexDirection:'column', gap:4, fontSize:11}}>
        <div>● R4 — Andreas posts <strong style={{color:'var(--d1-energy)'}}>140</strong> (T20·T20·D10)</div>
        <div>● R6 — Jonas busts on 36</div>
        <div>● R8 — Checkout <strong style={{color:'var(--d1-energy)'}}>T20·D20</strong> takes the leg</div>
      </div>
    </div>

    <div style={{padding:'10px 12px', display:'flex', gap:8, borderTop:'1px solid var(--d1-line)'}}>
      <div className="btn3 ghost">HOME</div>
      <div className="btn3 outline">↶ UNDO LAST</div>
      <div style={{flex:1}}/>
      <div className="btn3 primary">REMATCH →</div>
    </div>
  </div>
);

/* CRICKET — colour stub only */
const Cricketv4 = () => (
  <DCSection id="cricket-v4" title="Cricket · colour-only refresh (full redesign deferred)">
    <DCArtboard id="crk-stub" label="Recoloured to indigo+amber" width={540} height={720}><CrkStub/></DCArtboard>
  </DCSection>
);

const CrkStub = () => (
  <div className="tab3 d1">
    <div className="dot"/>
    <div className="broadcast">
      <div style={{padding:'8px 12px', fontFamily:'var(--mono)', fontWeight:800}}>← BACK</div>
      <div className="meta" style={{flex:1, textAlign:'center'}}>CRICKET</div>
      <div style={{padding:'8px 14px'}}>⚙</div>
    </div>

    <div className="players-strip">
      {[{n:'ANDREAS',s:40,a:true},{n:'JONAS',s:15,a:false},{n:'MIA',s:0,a:false}].map(p=>(
        <div key={p.n} style={{background: p.a ? 'rgba(255,179,0,0.10)' : 'transparent'}}>
          <div className="label-tiny">{p.n}</div>
          <div style={{fontFamily:'var(--display)', fontSize:24, lineHeight:1, marginTop:2, color:p.a?'var(--d1-energy)':'var(--d1-text)'}}>{p.s}</div>
          <div className="label-tiny" style={{fontSize:9}}>pts</div>
        </div>
      ))}
    </div>

    {/* Existing matrix layout — just recoloured */}
    <div style={{padding:'10px 12px', flex:1}}>
      {[20,19,18,17,16,15,'B'].map((t,i)=>{
        const aMarks = [3,2,0,0,0,0,0][i];
        const closed = aMarks >= 3;
        return (
          <div key={t} style={{display:'flex', alignItems:'center', gap:8, padding:'8px 10px', marginBottom:4, background: closed?'rgba(255,179,0,0.12)':'var(--d1-bg-1)', border:'1px solid var(--d1-line)', borderRadius:8}}>
            <div style={{width:36, fontFamily:'var(--display)', fontSize:24, color: closed?'var(--d1-energy)':'var(--d1-text)'}}>{t}</div>
            {i === 0 ? (
              <div style={{flex:3, display:'flex', gap:4}}>
                <div style={{flex:1, padding:'8px 0', textAlign:'center', background:'var(--d1-bg-2)', borderRadius:6, fontFamily:'var(--display)', fontSize:14}}>S</div>
                <div style={{flex:1, padding:'8px 0', textAlign:'center', background:'var(--d1-bg-2)', borderRadius:6, fontFamily:'var(--display)', fontSize:14}}>D</div>
                <div style={{flex:1, padding:'8px 0', textAlign:'center', background:'var(--d1-energy)', color:'#000', borderRadius:6, fontFamily:'var(--display)', fontSize:14}}>T</div>
              </div>
            ) : (
              <div style={{flex:3, display:'flex', alignItems:'center', gap:4}}>
                <div style={{flex:1, height:8, background:'var(--d1-bg-2)', borderRadius:4, overflow:'hidden'}}>
                  <div style={{width:`${(aMarks/3)*100}%`, height:'100%', background:'var(--d1-energy)'}}/>
                </div>
                <span className="label-tiny" style={{fontSize:9}}>{aMarks}/3</span>
              </div>
            )}
            <div style={{flex:1, height:8, background:'var(--d1-bg-2)', borderRadius:4, overflow:'hidden'}}>
              <div style={{width:'33%', height:'100%', background:'var(--d1-chrome)'}}/>
            </div>
            <div style={{flex:1, height:8, background:'var(--d1-bg-2)', borderRadius:4, overflow:'hidden'}}>
              <div style={{width:'0%', height:'100%', background:'var(--d1-energy-2)'}}/>
            </div>
          </div>
        );
      })}
    </div>

    <div style={{padding:'10px 12px', display:'flex', gap:8, borderTop:'1px solid var(--d1-line)'}}>
      <div className="btn3 outline">↶ UNDO</div>
      <div className="btn3 ghost">MISS</div>
      <div style={{flex:1}}/>
      <div className="btn3 primary">END TURN</div>
    </div>

    <N top={50} right={-160} width={160}>Same layout as today — just recoloured. Full redesign deferred until X01 ships.</N>
  </div>
);

window.X01v4 = X01v4;
window.Setupv4 = Setupv4;
window.PostGamev4 = PostGamev4;
window.Cricketv4 = Cricketv4;
