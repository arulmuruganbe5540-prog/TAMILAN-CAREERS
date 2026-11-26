/* Mangaiyarkarasi global Admin table theme. Reads the preset saved by Table Style Studio. */
(()=> {
 'use strict';
 const key='mangai_table_style';
 const families=[
  {name:'Grass & Nature',colors:['#174b35','#286f40','#4b9a63','#a7d88c','#e0f0c9']},
  {name:'Ocean & Blue',colors:['#102e50','#145b87','#218cba','#70c6df','#d8f4ff']},
  {name:'Royal & Gold',colors:['#30213f','#563b6c','#94704c','#d8b96e','#f4e2b5']},
  {name:'Modern & Neutral',colors:['#26313c','#465563','#71808c','#aab4bc','#e5e9ec']},
  {name:'Vivid & Bright',colors:['#51204b','#8c2860','#c64b62','#ee9666','#ffe0a8']}
 ];
 function palette(index){
  const safe=Number.isInteger(index)&&index>=0&&index<100?index:0;
  const family=families[Math.floor(safe/20)],variant=safe%10,c=family.colors;
  return {head:variant===7?c[0]:variant===9?c[1]:c[1],cell:'#101d2b',alt:variant===5?'#172b3d':'#172638',line:variant===3?c[2]:'#34465a',hover:c[0],accent:c[2]};
 }
 function apply(){
  let index=0;
  try{const saved=localStorage.getItem(key);if(saved!==null)index=Number(saved)}catch(_){}
  const p=palette(index),root=document.documentElement;
  root.style.setProperty('--mangai-table-head',p.head);
  root.style.setProperty('--mangai-table-cell',p.cell);
  root.style.setProperty('--mangai-table-alt',p.alt);
  root.style.setProperty('--mangai-table-line',p.line);
  root.style.setProperty('--mangai-table-hover',p.hover);
  root.style.setProperty('--mangai-table-accent',p.accent);
  if(!document.getElementById('mangai-global-table-style')){
   const style=document.createElement('style');style.id='mangai-global-table-style';
   style.textContent='body table{border-collapse:separate;border-spacing:0}body table thead th{background:var(--mangai-table-head,#286f40)!important;color:#fff!important;border-color:var(--mangai-table-line,#34465a)!important}body table tbody td{background:var(--mangai-table-cell,#101d2b)!important;color:#edf3fa!important;border-color:var(--mangai-table-line,#34465a)!important}body table tbody tr:nth-child(even) td{background:var(--mangai-table-alt,#172638)!important}body table tbody tr:hover td{background:var(--mangai-table-hover,#174b35)!important}body table .pill,body table .badge{background:var(--mangai-table-accent,#4b9a63)}';
   document.head.appendChild(style);
  }
 }
 if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',apply,{once:true});else apply();
 window.addEventListener('storage',event=>{if(event.key===key)apply()});
})();
