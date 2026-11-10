import io, json, struct, sys
from pathlib import Path
from PIL import Image

def optimize(path, limit):
    raw = path.read_bytes()
    magic, version, size = struct.unpack_from('<4sII', raw)
    assert magic == b'glTF' and version == 2 and size == len(raw)
    jl, jt = struct.unpack_from('<II', raw, 12)
    doc = json.loads(raw[20:20+jl])
    bl, bt = struct.unpack_from('<II', raw, 20+jl)
    blob = raw[28+jl:28+jl+bl]
    imgs = {x['bufferView']: x for x in doc.get('images', []) if 'bufferView' in x}
    out = bytearray()
    for i, view in enumerate(doc['bufferViews']):
        assert view.get('buffer', 0) == 0
        data = blob[view.get('byteOffset', 0):view.get('byteOffset', 0)+view['byteLength']]
        if i in imgs:
            im = Image.open(io.BytesIO(data)); im.load()
            if max(im.size) > limit:
                im.thumbnail((limit, limit), Image.Resampling.LANCZOS)
            alpha = 'A' in im.getbands() and im.getchannel('A').getextrema()[0] < 255
            b = io.BytesIO()
            if alpha:
                im.save(b, format='PNG', optimize=True); mime='image/png'
            else:
                im.convert('RGB').save(b, format='JPEG', quality=94, subsampling=0, optimize=True); mime='image/jpeg'
            data = b.getvalue(); imgs[i]['mimeType'] = mime
        while len(out)%4: out.append(0)
        view['byteOffset'] = len(out); view['byteLength'] = len(data); out.extend(data)
    while len(out)%4: out.append(0)
    doc['buffers'][0]['byteLength'] = len(out)
    j = json.dumps(doc, separators=(',', ':'), ensure_ascii=False).encode('utf-8')
    j += b' ' * (-len(j)%4)
    result = struct.pack('<4sII', b'glTF', 2, 12+8+len(j)+8+len(out)) + struct.pack('<II', len(j), 0x4e4f534a)+j+struct.pack('<II', len(out), 0x004e4942)+out
    path.write_bytes(result)
    print(path, len(raw), len(result))

if __name__ == '__main__':
    optimize(Path(sys.argv[1]), int(sys.argv[2]))
