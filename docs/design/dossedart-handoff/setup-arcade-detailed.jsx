// DOSSEDART — X01 Setup screen (cleaned)
// X01 is selected on the home screen, so this page is just
// players + rules. No mode chip, no throw-order strip.
//
// Spec (per design brief):
//   • Start score:   301 / 501 / 701
//   • Out rule:      FREE-OUT / DOUBLE-OUT / MASTER-OUT
//   • No-Bust:       optional toggle
//   • Handicap:      optional — per-player startscore override
//   • Random order:  optional toggle (shuffles slot numbers)
// Player tile uses the locked Variant A pattern: avatar left,
// name + last-5 W/L pips stacked on the right.

const AW = 820, AH = 1180;

// ─── Cast ───────────────────────────────────────────────────────
const CAST = [
  { handle:'AND', name:'Andreas',  form:['W','W','L','W','W'], selected:true,  slot:1 },
  { handle:'JON', name:'Jonas',    form:['L','W','L','W','L'], selected:true,  slot:2 },
  { handle:'MIA', name:'Mia',      form:['W','L','L','W','L'], selected:true,  slot:3 },
  { handle:'EVA', name:'Eva',      form:['L','W','W','L','W'], selected:false, slot:null },
  { handle:'OLA', name:'Ola',      form:['L','L','W','L','L'], selected:false, slot:null },
  { handle:'KIM', name:'Kim',      form:['L','L','L','W','L'], selected:false, slot:null },
];

const CFG = {
  startScore:   501,
  outRule:      'DOUBLE',     // FREE | DOUBLE | MASTER
  noBust:       false,
  handicap:     true,
  randomOrder:  false,
  // when handicap is on, slot → startscore override
  handicapBy:   { 1: 501, 2: 401, 3: 301 },
};

const YELLOW  = '#FFD200';
const MAGENTA = '#FF00AA';
const CYAN    = '#00E5FF';
const PURPLE  = '#7B3FFF';
const BG      = '#0a0014';
const SURFACE = '#1a0030';

// ─── Top bar ────────────────────────────────────────────────────
const TopBar = () => (
  <div style={{padding:'14px 28px', background:'#000', borderBottom:`2px solid ${MAGENTA}`, display:'flex', alignItems:'center', gap:14}}>
    <div style={{fontFamily:'"VT323", monospace', fontSize:20, color:CYAN, letterSpacing:2}}>◀ HOME</div>
    <div style={{flex:1, textAlign:'center', fontFamily:'"Press Start 2P", monospace', fontSize:14, color:YELLOW, letterSpacing:2, textShadow:`0 0 8px ${YELLOW}88`}}>NEW MATCH</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:18, color:'rgba(255,255,255,0.55)', letterSpacing:2}}>1CR</div>
  </div>
);

// ─── Rules (start score + out rule + toggles) ───────────────────
const RulesRow = () => {
  const Chip = ({ label, on, fontSize=11 }) => (
    <div style={{
      flex: 1,
      padding:'12px 6px',
      textAlign:'center',
      background: on ? YELLOW : SURFACE,
      border: `2px solid ${on ? YELLOW : MAGENTA}`,
      color: on ? BG : '#fff',
      fontFamily:'"Press Start 2P", monospace',
      fontSize,
      letterSpacing: .5,
      boxShadow: on ? `0 0 10px ${YELLOW}88` : 'none',
    }}>{label}</div>
  );
  const Toggle = ({ label, on, accent=CYAN }) => (
    <div style={{display:'flex', alignItems:'center', gap:10, padding:'10px 12px', background: on ? `${accent}22` : SURFACE, border: `2px solid ${on ? accent : MAGENTA}`, boxShadow: on ? `0 0 10px ${accent}55` : 'none'}}>
      <div style={{width:36, height:18, background: on ? accent : 'rgba(255,255,255,0.12)', position:'relative', flexShrink:0}}>
        <div style={{position:'absolute', top:1, left: on?20:1, width:14, height:14, background: on ? BG : '#fff', transition:'all .15s'}}></div>
      </div>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:10, color:'#fff', letterSpacing:1}}>{label}</div>
    </div>
  );
  const Section = ({ label, children }) => (
    <div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.45)', letterSpacing:2, marginBottom:6}}>{label}</div>
      {children}
    </div>
  );
  return (
    <div style={{padding:'18px 28px 16px', borderBottom:`1px dashed ${MAGENTA}66`, display:'flex', flexDirection:'column', gap:12}}>
      <div style={{display:'flex', alignItems:'center', justifyContent:'space-between'}}>
        <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1.5}}>► RULES</div>
      </div>
      <Section label="OUT RULE">
        <div style={{display:'flex', gap:4}}>
          <Chip label="FREE OUT"   on={CFG.outRule==='FREE'}/>
          <Chip label="DOUBLE OUT" on={CFG.outRule==='DOUBLE'}/>
          <Chip label="MASTER OUT" on={CFG.outRule==='MASTER'}/>
        </div>
      </Section>
      <Section label="OPTIONS">
        <div style={{display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:6}}>
          <Toggle label="NO-BUST"      on={CFG.noBust}      accent={MAGENTA}/>
          <Toggle label="HANDICAP"     on={CFG.handicap}    accent={CYAN}/>
          <Toggle label="RANDOM ORDER" on={CFG.randomOrder} accent={PURPLE}/>
        </div>
      </Section>
    </div>
  );
};

// ─── Form pips + locked picker tile (variant A) ─────────────────
const FormPips = ({ form, color, size=12 }) => (
  <div style={{display:'flex', gap:3}}>
    {form.map((f, i) => (
      <div key={i} style={{
        width:size, height:size,
        background: f==='W' ? color : 'transparent',
        border: `1.5px solid ${f==='W' ? color : 'rgba(255,255,255,0.22)'}`,
        color: f==='W' ? BG : 'rgba(255,255,255,0.32)',
        display:'flex', alignItems:'center', justifyContent:'center',
        fontFamily:'"Press Start 2P", monospace', fontSize: size <= 11 ? 6 : 7,
      }}>{f}</div>
    ))}
  </div>
);

const PickerTile = ({ p }) => {
  const c = p.selected ? YELLOW : MAGENTA;
  const hcap = p.selected && CFG.handicap ? CFG.handicapBy[p.slot] : null;
  return (
    <div style={{padding:'14px', background: p.selected?'rgba(255,210,0,0.06)':SURFACE, border:`3px solid ${c}`, boxShadow: p.selected?`0 0 12px ${c}55, inset 0 0 14px ${c}22`:'none', position:'relative', opacity: p.selected?1:0.7}}>
      {p.selected && (
        <div style={{position:'absolute', top:-9, right:-6, padding:'3px 8px', background:YELLOW, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:10, letterSpacing:1, boxShadow:`0 0 8px ${YELLOW}`, transform:'rotate(4deg)'}}>P{p.slot}</div>
      )}
      <div style={{display:'flex', alignItems:'center', gap:12}}>
        <div style={{width:46, height:46, background:BG, border:`2px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:c, letterSpacing:1, textShadow:`0 0 6px ${c}aa`, flexShrink:0}}>{p.handle}</div>
        <div style={{flex:1, minWidth:0, display:'flex', flexDirection:'column', alignItems:'center', gap:6}}>
          <div style={{fontFamily:'"VT323", monospace', fontSize:20, color:'#fff', letterSpacing:1, lineHeight:1}}>{p.name.toUpperCase()}</div>
          <FormPips form={p.form} color={c} size={12}/>
        </div>
      </div>
      {hcap && (
        <div style={{marginTop:10, padding:'6px 8px', background:`${CYAN}15`, border:`1px dashed ${CYAN}88`, display:'flex', alignItems:'center', justifyContent:'space-between'}}>
          <div style={{fontFamily:'"VT323", monospace', fontSize:12, color:CYAN, letterSpacing:1.5}}>HANDICAP START</div>
          <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:13, color:CYAN, textShadow:`0 0 6px ${CYAN}aa`}}>{hcap}</div>
        </div>
      )}
    </div>
  );
};

// ─── Cast ────────────────────────────────────────────────────────
// ─── Add player tile (slots into the picker grid) ──────────────
const AddPlayerTile = () => (
  <div style={{padding:'14px', background:'transparent', border:`3px dashed ${CYAN}`, display:'flex', flexDirection:'column', alignItems:'center', justifyContent:'center', gap:8, minHeight:118, color:CYAN, boxShadow:`inset 0 0 14px ${CYAN}22`}}>
    <div style={{width:46, height:46, border:`2px solid ${CYAN}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:22, color:CYAN, textShadow:`0 0 6px ${CYAN}aa`}}>+</div>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1.5, textShadow:`0 0 6px ${CYAN}aa`}}>ADD PLAYER</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.5)', letterSpacing:1.5}}>NEW OR GUEST</div>
  </div>
);

const Cast = () => (
  <div style={{padding:'16px 28px 0'}}>
    <div style={{display:'flex', alignItems:'center', justifyContent:'space-between', marginBottom:12}}>
      <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:CYAN, letterSpacing:1.5}}>► PICK YOUR FIGHTERS</div>
      <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:YELLOW, letterSpacing:2}}>3 / 6 READY{CFG.randomOrder ? ' · ORDER RANDOM' : ''}</div>
    </div>
    <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:8}}>
      {CAST.map(p => <PickerTile key={p.handle} p={p}/>)}
      <AddPlayerTile/>
    </div>
    <div style={{display:'flex', alignItems:'center', justifyContent:'center', gap:14, marginTop:10, fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:2}}>
      <span>+ ADD GUEST</span>
      <span style={{color:MAGENTA}}>·</span>
      <span>MANAGE CAST</span>
    </div>
  </div>
);

// ─── Start ──────────────────────────────────────────────────────
const StartBtn = () => {
  const summary = [
    `${CAST.filter(p=>p.selected).length} PLAYERS`,
    `${CFG.outRule} OUT`,
    CFG.noBust       && 'NO-BUST',
    CFG.handicap    && 'HANDICAP',
    CFG.randomOrder && 'RANDOM ORDER',
  ].filter(Boolean).join(' · ');
  return (
    <div style={{padding:'14px 28px 18px', background:'#000', borderTop:`2px solid ${YELLOW}`}}>
      <div style={{padding:'18px 14px', background:`linear-gradient(180deg, ${YELLOW} 0%, #FFA500 100%)`, color:BG, fontFamily:'"Press Start 2P", monospace', fontSize:18, letterSpacing:2, textAlign:'center', boxShadow:`0 0 24px ${YELLOW}, inset 0 -4px 0 rgba(0,0,0,0.3)`, border:'3px solid #fff'}}>
        ▶ START MATCH ◀
      </div>
      <div style={{textAlign:'center', fontFamily:'"VT323", monospace', fontSize:16, color:'rgba(255,255,255,0.6)', letterSpacing:3, marginTop:10}}>{summary}</div>
    </div>
  );
};

// ─── Container ──────────────────────────────────────────────────
const SetupRosterDetailed = () => {
  const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
  return (
    <div style={{width:AW, height:AH, background:BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}></div>
      <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.6) 100%)', pointerEvents:'none', zIndex:4}}></div>
      <TopBar/>
      <RulesRow/>
      <Cast/>
      <div style={{flex:1}}></div>
      <StartBtn/>
    </div>
  );
};

const SetupArcadeDetailed = () => (
  <DCSection
    id="su-x01-d"
    title="X01 — Setup (cleaned v2)"
    subtitle="Start score row removed — picked on the home screen. Rules section now: OUT RULE + OPTIONS only. Picker grid gets a dashed cyan ADD PLAYER tile that sits in line with the cast.">
    <DCArtboard id="setup-detailed" label="X01 setup — cleaned" width={AW} height={AH}><SetupRosterDetailed/></DCArtboard>
  </DCSection>
);

window.SetupArcadeDetailed = SetupArcadeDetailed;
