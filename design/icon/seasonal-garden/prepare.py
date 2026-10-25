"""Extract clean SVG contours from the approved A-style, diagonal-window sources.

uv run --with vtracer==0.6.15 --with pillow python prepare.py
"""
from collections import deque
from io import BytesIO
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET
from PIL import Image
import vtracer

ROOT=Path(__file__).resolve().parent
FLOWERS=['plum','magnolia','crabapple','gardenia','lotus','osmanthus','chrysanthemum','camellia']
records=[]
for flower in FLOWERS:
    full=ROOT/'paths'/f'{flower}.svg'
    alpha=Image.open(ROOT/'source'/f'{flower}.png').convert('RGBA').getchannel('A')
    alpha.thumbnail((600,600),Image.Resampling.LANCZOS)
    w,h=alpha.size
    pixels=bytearray(1 if x>=210 else 0 for x in alpha.tobytes())
    clean=bytearray(w*h)
    areas=[]
    for start in range(w*h):
        if not pixels[start]: continue
        pixels[start]=0
        queue=deque([start]); component=[]
        while queue:
            index=queue.popleft(); component.append(index)
            x,y=index%w,index//w
            neighbours=[]
            if x>0: neighbours.append(index-1)
            if x+1<w: neighbours.append(index+1)
            if y>0: neighbours.append(index-w)
            if y+1<h: neighbours.append(index+w)
            for neighbour in neighbours:
                if pixels[neighbour]: pixels[neighbour]=0; queue.append(neighbour)
        if len(component)>=180:
            areas.append(len(component))
            for index in component: clean[index]=255
    mask=Image.frombytes('L',(w,h),bytes(clean))
    bounds=mask.getbbox()
    if not bounds: raise ValueError(f'Empty silhouette: {flower}')
    stream=BytesIO()
    mask.point(lambda x:0 if x else 255).convert('RGB').save(stream,format='PNG')
    traced=vtracer.convert_raw_image_to_svg(stream.getvalue(),img_format='png',colormode='binary',
                mode='spline',filter_speckle=1,corner_threshold=90,length_threshold=5.0,
                splice_threshold=45,path_precision=2)
    tree=ET.fromstring(traced)
    paths=[]
    for node in tree.iter():
        if node.tag.rsplit('}',1)[-1]!='path': continue
        if node.attrib.get('fill','#000000').lower() in ['#ffffff','#fff','white']: continue
        node.attrib.pop('fill',None)
        attrs=' '.join(f'{k}="{v}"' for k,v in node.attrib.items())
        paths.append(f'<path {attrs}/>')
    x0,y0,x1,y1=bounds
    # Normalize the entire diagonal branch, including its root outside the window.
    # The native circular rim is centred at (64,64), radius ~46.5 on this grid;
    # the lower-left endpoint must not be pulled back onto the bottom of that rim.
    scale=min(84/(x1-x0),88/(y1-y0))
    tx=64-(x0+x1)/2*scale; ty=66-(y0+y1)/2*scale
    body=f'<g fill="currentColor" transform="translate({tx:.4f} {ty:.4f}) scale({scale:.6f})">'+''.join(paths)+'</g>'
    full.write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">'+body+'</svg>\n')
    tree=ET.fromstring(full.read_bytes())
    full_paths=sum(n.tag.rsplit('}',1)[-1]=='path' for n in tree.iter())
    # At menu size, enclosed leaf veins and tiny centre holes add noise. Keep each
    # connected piece's outer contour, retaining the principal open petal gaps.
    for node in tree.iter():
        if node.tag.rsplit('}',1)[-1]=='path':
            data=node.attrib['d']
            first_close=re.search(r'[Zz]',data)
            if first_close: node.attrib['d']=data[:first_close.end()]
    menu=full.with_name(f'{flower}-menu.svg')
    ET.register_namespace('', 'http://www.w3.org/2000/svg')
    menu.write_text(ET.tostring(tree,encoding='unicode')+'\n')
    records.append({'flower':flower,'paths':full_paths,'full_bytes':full.stat().st_size,'menu_bytes':menu.stat().st_size})
(ROOT/'vectorization.json').write_text(json.dumps(records,indent=2)+'\n')
print(json.dumps(records,indent=2))
