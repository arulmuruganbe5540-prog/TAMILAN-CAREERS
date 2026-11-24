/* TAMILAN CAREERS — Orbit table visual enhancer
   Adds a consistent orbital header and responsive table skin without changing table data or handlers. */
(function(){
  if (window.__tcOrbitTablesLoaded) return;
  window.__tcOrbitTablesLoaded = true;
  const path = location.pathname.toLowerCase();
  let accent = '#087bc1', soft = '#e7f5ff', label = 'CAREER INFORMATION GRID', symbol = 'TC';
  if (path.includes('international')) { accent = '#8652c8'; soft = '#f1eaff'; label = 'GLOBAL CAREER ORBIT'; symbol = 'GLB'; }
  else if (path.includes('private') || path.includes('company')) { accent = '#07966c'; soft = '#e4f8ef'; label = 'CORPORATE CAREER GRID'; symbol = 'IN'; }
  else if (path.includes('super-admin')) { accent = '#6d5bd0'; soft = '#f0edff'; label = 'ADMIN DATA COMMAND'; symbol = 'ADM'; }
  const css = `
    .tc-orbit-heading{--tc-orbit-accent:${accent};--tc-orbit-soft:${soft};position:relative;min-height:108px;margin:16px 0 12px;padding:15px;display:flex;align-items:center;justify-content:center;overflow:hidden;border:1px solid #203b59;border-radius:13px;background:radial-gradient(ellipse at 50% 130%,color-mix(in srgb,var(--tc-orbit-accent),transparent 78%),transparent 60%),linear-gradient(112deg,#0b1b30,#132e4b 60%,#0a1b30)}
    .tc-orbit-heading:before,.tc-orbit-heading:after{content:"";position:absolute;left:50%;top:50%;translate:-50% -50%;width:300px;height:95px;border:1px solid color-mix(in srgb,var(--tc-orbit-accent),transparent 45%);border-radius:50%;transform:rotate(-12deg);box-shadow:0 0 22px color-mix(in srgb,var(--tc-orbit-accent),transparent 80%)}
    .tc-orbit-heading:after{width:410px;height:130px;transform:rotate(13deg);opacity:.5}
    .tc-orbit-core{position:relative;z-index:1;display:flex;align-items:center;gap:12px;padding:10px 16px;border:1px solid color-mix(in srgb,var(--tc-orbit-accent),white 35%);border-radius:11px;background:rgba(5,18,33,.9);max-width:100%;box-shadow:0 0 24px color-mix(in srgb,var(--tc-orbit-accent),transparent 78%)}
    .tc-orbit-symbol{width:40px;height:40px;display:grid;place-items:center;border-radius:11px;background:var(--tc-orbit-accent);color:#fff;font-weight:900;font-size:12px;flex:0 0 40px}
    .tc-orbit-copy{min-width:0}.tc-orbit-copy b{display:block;color:#fff;font-size:13px}.tc-orbit-copy small{display:block;color:#b8c8da;font-size:10px;margin-top:3px}
    .tc-orbit-wrap{max-width:100%;overflow-x:auto;border:1px solid #dce5ef;border-radius:11px;background:#fff;box-shadow:0 6px 18px rgba(15,35,60,.06);-webkit-overflow-scrolling:touch}
    .tc-orbit-wrap:before{content:"";display:block;height:4px;background:linear-gradient(90deg,${accent},color-mix(in srgb,${accent},white 58%),${accent})}
    .tc-orbit-wrap table{width:100%;border-collapse:collapse;background:#fff}
    .tc-orbit-wrap th{background:#f4f7fc!important;color:#243b57!important;border-bottom:1px solid #dce5ef!important}
    .tc-orbit-wrap td{border-bottom:1px solid #edf1f6!important}
    .tc-orbit-wrap tbody tr:hover{background:var(--tc-orbit-soft)!important}
    @media(max-width:600px){.tc-orbit-heading{min-height:96px;padding:10px}.tc-orbit-heading:before{width:245px}.tc-orbit-heading:after{width:330px}.tc-orbit-core{padding:9px 11px;gap:9px}.tc-orbit-symbol{width:35px;height:35px;flex-basis:35px}}
  `;
  const style = document.createElement('style'); style.id='tc-orbit-table-style'; style.textContent=css; document.head.appendChild(style);
  document.querySelectorAll('table').forEach((table,index)=>{
    if(table.classList.contains('orbit-table') || table.closest('.orbit-table-wrap') || table.dataset.tcOrbitEnhanced==='1') return;
    const parent=table.parentElement;
    if(!parent) return;
    const heading=document.createElement('div');
    heading.className='tc-orbit-heading';
    heading.innerHTML='<div class="tc-orbit-core"><span class="tc-orbit-symbol">'+symbol+'</span><span class="tc-orbit-copy"><b>'+label+'</b><small>Structured records · Responsive data view · TAMILAN CAREERS</small></span></div>';
    parent.parentNode.insertBefore(heading,parent);
    parent.classList.add('tc-orbit-wrap');
    table.dataset.tcOrbitEnhanced='1';
  });
})();