// DOSSEDART — Player picker variants
// Goal: explore less-cluttered presentations of the cast grid while
// keeping the W/L last-5 form pips (the part that worked).
// Strips: rating, win-%, head-to-head, "press to join" affordance,
//   "last seen" stamps, slot rotation flair.
// Keeps:  arcade language (yellow/magenta/cyan, Press Start 2P + VT323),
//   selection state with slot number, W/L form pips.

const PV_W = 460;
const PV_H = 920;

const PV_CAST = [
  { handle:'AND', name:'Andreas',  form:['W','W','L','W','W'], selected:true,  slot:1 },
  { handle:'JON', name:'Jonas',    form:['L','W','L','W','L'], selected:true,  slot:2 },
  { handle:'MIA', name:'Mia',      form:['W','L','L','W','L'], selected:true,  slot:3 },
  { handle:'EVA', name:'Eva',      form:['L','W','W','L','W'], selected:false, slot:null },
  { handle:'OLA', name:'Ola',      form:['L','L','W','L','L'], selected:false, slot:null },
  { handle:'KIM', name:'Kim',      form:['L','L','L','W','L'], selected:false, slot:null },
];

const PV_YELLOW  = '#FFD200';
const PV_MAGENTA = '#FF00AA';
const PV_CYAN    = '#00E5FF';
const PV_BG      = '#0a0014';
const PV_SURFACE = '#1a0030';

// Shared scanlines + vignette
const PvFrame = ({ children }) => {
  const scan = `repeating-linear-gradient(0deg, rgba(0,0,0,0) 0px, rgba(0,0,0,0) 2px, rgba(0,0,0,0.3) 3px, rgba(0,0,0,0) 4px)`;
  return (
    <div style={{width:PV_W, height:PV_H, background:PV_BG, color:'#fff', fontFamily:'"Press Start 2P", monospace', display:'flex', flexDirection:'column', overflow:'hidden', position:'relative'}}>
      <div style={{position:'absolute', inset:0, backgroundImage:scan, pointerEvents:'none', zIndex:5}}/>
      <div style={{position:'absolute', inset:0, background:'radial-gradient(ellipse at center, transparent 50%, rgba(0,0,0,0.5) 100%)', pointerEvents:'none', zIndex:4}}/>
      {children}
    </div>
  );
};

const PvHeader = ({ label }) => (
  <div style={{padding:'14px 22px 10px', display:'flex', alignItems:'center', justifyContent:'space-between', borderBottom:`1px dashed ${PV_MAGENTA}66`}}>
    <div style={{fontFamily:'"Press Start 2P", monospace', fontSize:11, color:PV_CYAN, letterSpacing:1.5}}>► PICK FIGHTERS</div>
    <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:PV_YELLOW, letterSpacing:2}}>{label}</div>
  </div>
);

// W/L pips — kept consistent across variants
const FormPips = ({ form, color, size=12 }) => (
  <div style={{display:'flex', gap:3}}>
    {form.map((f, i) => (
      <div key={i} style={{
        width:size, height:size,
        background: f==='W' ? color : 'transparent',
        border: `1.5px solid ${f==='W' ? color : 'rgba(255,255,255,0.22)'}`,
        color: f==='W' ? PV_BG : 'rgba(255,255,255,0.32)',
        display:'flex', alignItems:'center', justifyContent:'center',
        fontFamily:'"Press Start 2P", monospace', fontSize: size <= 11 ? 6 : 7,
      }}>{f}</div>
    ))}
  </div>
);

// ─── Variant A · Stripped 2-col (LOCKED) ────────────────────────
// Avatar left, name + W/L pips stacked on the right. W/L sits
// directly under the name rather than across the bottom of the
// tile — keeps the eye in one column, less visual chatter.
const VariantA = () => {
  const Tile = ({ p }) => {
    const c = p.selected ? PV_YELLOW : PV_MAGENTA;
    return (
      <div style={{padding:'14px 14px', background: p.selected?'rgba(255,210,0,0.06)':PV_SURFACE, border:`3px solid ${c}`, boxShadow: p.selected?`0 0 12px ${c}55, inset 0 0 14px ${c}22`:'none', position:'relative', opacity: p.selected?1:0.7}}>
        {p.selected && (
          <div style={{position:'absolute', top:-9, right:-6, padding:'3px 8px', background:PV_YELLOW, color:PV_BG, fontFamily:'"Press Start 2P", monospace', fontSize:10, letterSpacing:1, boxShadow:`0 0 8px ${PV_YELLOW}`, transform:'rotate(4deg)'}}>P{p.slot}</div>
        )}
        <div style={{display:'flex', alignItems:'center', gap:12}}>
          <div style={{width:46, height:46, background:PV_BG, border:`2px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:c, letterSpacing:1, textShadow:`0 0 6px ${c}aa`, flexShrink:0}}>{p.handle}</div>
          <div style={{flex:1, minWidth:0, display:'flex', flexDirection:'column', alignItems:'center', gap:6}}>
            <div style={{fontFamily:'"VT323", monospace', fontSize:20, color:'#fff', letterSpacing:1, lineHeight:1}}>{p.name.toUpperCase()}</div>
            <FormPips form={p.form} color={c} size={12}/>
          </div>
        </div>
      </div>
    );
  };
  return (
    <PvFrame>
      <PvHeader label="3 / 6 READY"/>
      <div style={{padding:'14px 22px', flex:1}}>
        <div style={{display:'grid', gridTemplateColumns:'1fr 1fr', gap:8}}>
          {PV_CAST.map(p => <Tile key={p.handle} p={p}/>)}
        </div>
      </div>
      <div style={{padding:'12px 22px', borderTop:`1px dashed ${PV_MAGENTA}66`, fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:2, textAlign:'center'}}>
        + ADD GUEST · MANAGE CAST
      </div>
    </PvFrame>
  );
};

// ─── Variant B · 3-col compact ──────────────────────────────────
// Smaller tiles, denser. Form pips compress to 5 tiny squares.
const VariantB = () => {
  const Tile = ({ p }) => {
    const c = p.selected ? PV_YELLOW : PV_MAGENTA;
    return (
      <div style={{padding:'10px 8px 8px', background: p.selected?'rgba(255,210,0,0.06)':PV_SURFACE, border:`2px solid ${c}`, boxShadow: p.selected?`0 0 10px ${c}55, inset 0 0 10px ${c}22`:'none', position:'relative', opacity: p.selected?1:0.65, textAlign:'center'}}>
        {p.selected && (
          <div style={{position:'absolute', top:-8, right:-4, width:18, height:18, background:PV_YELLOW, color:PV_BG, fontFamily:'"Press Start 2P", monospace', fontSize:9, display:'flex', alignItems:'center', justifyContent:'center', boxShadow:`0 0 6px ${PV_YELLOW}`}}>{p.slot}</div>
        )}
        <div style={{width:42, height:42, margin:'0 auto 6px', background:PV_BG, border:`2px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:11, color:c, letterSpacing:.5, textShadow:`0 0 6px ${c}aa`}}>{p.handle}</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:15, color:'#fff', letterSpacing:1, lineHeight:1, marginBottom:6}}>{p.name.toUpperCase()}</div>
        <div style={{display:'flex', justifyContent:'center'}}>
          <FormPips form={p.form} color={c} size={9}/>
        </div>
      </div>
    );
  };
  return (
    <PvFrame>
      <PvHeader label="3 / 6 READY"/>
      <div style={{padding:'14px 18px', flex:1}}>
        <div style={{display:'grid', gridTemplateColumns:'1fr 1fr 1fr', gap:6}}>
          {PV_CAST.map(p => <Tile key={p.handle} p={p}/>)}
        </div>
      </div>
      <div style={{padding:'12px 22px', borderTop:`1px dashed ${PV_MAGENTA}66`, fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:2, textAlign:'center'}}>
        + ADD GUEST · MANAGE CAST
      </div>
    </PvFrame>
  );
};

// ─── Variant C · Row list ───────────────────────────────────────
// Single column. Each player a wide row: avatar | name | form pips
// | slot badge. Generous whitespace, calmest read.
const VariantC = () => {
  const Row = ({ p }) => {
    const c = p.selected ? PV_YELLOW : PV_MAGENTA;
    return (
      <div style={{padding:'12px 14px', background: p.selected?'rgba(255,210,0,0.06)':PV_SURFACE, border:`2px solid ${c}`, boxShadow: p.selected?`0 0 10px ${c}44, inset 0 0 10px ${c}22`:'none', display:'flex', alignItems:'center', gap:14, opacity: p.selected?1:0.7}}>
        <div style={{width:44, height:44, background:PV_BG, border:`2px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:12, color:c, letterSpacing:1, textShadow:`0 0 6px ${c}aa`, flexShrink:0}}>{p.handle}</div>
        <div style={{flex:1, minWidth:0}}>
          <div style={{fontFamily:'"VT323", monospace', fontSize:21, color:'#fff', letterSpacing:1.5, lineHeight:1, marginBottom:6}}>{p.name.toUpperCase()}</div>
          <FormPips form={p.form} color={c} size={12}/>
        </div>
        {p.selected ? (
          <div style={{padding:'6px 10px', background:PV_YELLOW, color:PV_BG, fontFamily:'"Press Start 2P", monospace', fontSize:11, letterSpacing:1, boxShadow:`0 0 8px ${PV_YELLOW}aa`}}>P{p.slot}</div>
        ) : (
          <div style={{width:24, height:24, border:`2px dashed ${PV_MAGENTA}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"VT323", monospace', fontSize:18, color:PV_MAGENTA}}>+</div>
        )}
      </div>
    );
  };
  return (
    <PvFrame>
      <PvHeader label="3 / 6 READY"/>
      <div style={{padding:'14px 22px', flex:1, display:'flex', flexDirection:'column', gap:8}}>
        {PV_CAST.map(p => <Row key={p.handle} p={p}/>)}
      </div>
      <div style={{padding:'12px 22px', borderTop:`1px dashed ${PV_MAGENTA}66`, fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:2, textAlign:'center'}}>
        + ADD GUEST · MANAGE CAST
      </div>
    </PvFrame>
  );
};

// ─── Variant D · Stacks (selected vs bench) ─────────────────────
// Selected players get full tiles up top with form pips.
// Bench (unselected) collapses to a row of small chips below —
// avatar + name only, tap to promote.
const VariantD = () => {
  const selected = PV_CAST.filter(p=>p.selected);
  const bench    = PV_CAST.filter(p=>!p.selected);

  const BigTile = ({ p }) => {
    const c = PV_YELLOW;
    return (
      <div style={{flex:1, padding:'12px 12px 14px', background:'rgba(255,210,0,0.06)', border:`3px solid ${c}`, boxShadow:`0 0 12px ${c}55, inset 0 0 14px ${c}22`, position:'relative', textAlign:'center'}}>
        <div style={{position:'absolute', top:-9, left:'50%', transform:'translateX(-50%)', padding:'3px 9px', background:c, color:PV_BG, fontFamily:'"Press Start 2P", monospace', fontSize:10, letterSpacing:1, boxShadow:`0 0 8px ${c}`}}>P{p.slot}</div>
        <div style={{width:46, height:46, margin:'4px auto 8px', background:PV_BG, border:`2px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:13, color:c, letterSpacing:1, textShadow:`0 0 6px ${c}aa`}}>{p.handle}</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:17, color:'#fff', letterSpacing:1.5, lineHeight:1, marginBottom:8}}>{p.name.toUpperCase()}</div>
        <div style={{display:'flex', justifyContent:'center'}}>
          <FormPips form={p.form} color={c} size={11}/>
        </div>
      </div>
    );
  };

  const BenchChip = ({ p }) => {
    const c = PV_MAGENTA;
    return (
      <div style={{padding:'8px 10px', background:PV_SURFACE, border:`2px solid ${c}`, display:'flex', alignItems:'center', gap:8, opacity:0.85}}>
        <div style={{width:26, height:26, background:PV_BG, border:`1.5px solid ${c}`, display:'flex', alignItems:'center', justifyContent:'center', fontFamily:'"Press Start 2P", monospace', fontSize:9, color:c, letterSpacing:.5, textShadow:`0 0 6px ${c}aa`, flexShrink:0}}>{p.handle}</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.85)', letterSpacing:1, lineHeight:1}}>{p.name.toUpperCase()}</div>
        <div style={{fontFamily:'"VT323", monospace', fontSize:14, color:c, letterSpacing:1, marginLeft:4}}>+</div>
      </div>
    );
  };

  return (
    <PvFrame>
      <PvHeader label="3 IN · 3 ON BENCH"/>
      <div style={{padding:'14px 22px 10px'}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.45)', letterSpacing:2, marginBottom:8}}>► IN THE MATCH</div>
        <div style={{display:'flex', gap:6}}>
          {selected.map(p => <BigTile key={p.handle} p={p}/>)}
        </div>
      </div>
      <div style={{padding:'14px 22px', flex:1}}>
        <div style={{fontFamily:'"VT323", monospace', fontSize:13, color:'rgba(255,255,255,0.45)', letterSpacing:2, marginBottom:8}}>► BENCH · TAP TO ADD</div>
        <div style={{display:'flex', flexDirection:'column', gap:6}}>
          {bench.map(p => <BenchChip key={p.handle} p={p}/>)}
        </div>
      </div>
      <div style={{padding:'12px 22px', borderTop:`1px dashed ${PV_MAGENTA}66`, fontFamily:'"VT323", monospace', fontSize:14, color:'rgba(255,255,255,0.5)', letterSpacing:2, textAlign:'center'}}>
        + ADD GUEST · MANAGE CAST
      </div>
    </PvFrame>
  );
};

// ─── Canvas section ─────────────────────────────────────────────
const PickerVariants = () => (
  <DCSection
    id="picker-variants"
    title="Player picker — locked"
    subtitle="A · stripped 2-col, with W/L pips moved up under the name (right of the avatar) instead of stretched across the bottom of the tile. Cleaner read, eye stays in one column. B / C / D parked.">
    <DCArtboard id="pv-a" label="A · Stripped 2-col (locked)" width={PV_W} height={PV_H}><VariantA/></DCArtboard>
  </DCSection>
);

window.PickerVariants = PickerVariants;
