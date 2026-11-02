"""Prepare public road geometry packs; clients download only saved-facility cells."""
import json, math
from collections import defaultdict
from pathlib import Path
import osmium
packs=defaultdict(list)
class Roads(osmium.SimpleHandler):
    def way(self,w):
        t=dict(w.tags)
        if 'highway' not in t or t['highway'] in ['construction','proposed']: return
        p=[[round(n.lon,6),round(n.lat,6)] for n in w.nodes if n.location.valid()]
        if len(p)<2:return
        lo,hi=min(x[0] for x in p),max(x[0] for x in p)
        so,no=min(x[1] for x in p),max(x[1] for x in p)
        if hi<124 or lo>132 or no<33 or so>39:return
        for x in range(math.floor(max(lo,124)*20),math.floor(min(hi,132)*20)+1):
            for y in range(math.floor(max(so,33)*20),math.floor(min(no,39)*20)+1):
                packs[f'{x}-{y}'].append({'id':str(w.id),'kind':'road','type':t['highway'],'name':t.get('name:ko',t.get('name','')),'points':p})
Roads().apply_file('.tools/offline-map-data/south-korea-261101.osm.pbf',locations=True,idx='flex_mem')
out=Path('.tools/saved-map-packs/v1');out.mkdir(parents=True,exist_ok=True)
for key,features in packs.items():
    (out/f'{key}.json').write_text(json.dumps({'schemaVersion':1,'source':'© OpenStreetMap contributors · Geofabrik','license':'ODbL 1.0','preparedAt':'2026-11-02','features':features},ensure_ascii=False,separators=(',',':')))
print(len(packs),'packs',sum(p.stat().st_size for p in out.glob('*.json')),'bytes')
