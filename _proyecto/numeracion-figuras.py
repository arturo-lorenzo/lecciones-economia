#!/usr/bin/env python3
# Post-render (solo HTML): Quarto numera las figuras con el ordinal del
# capítulo en el libro («Figura 35.1» en A36). Este script sustituye ese
# ordinal por el código del tema («Figura A36.1»), en los pies, en las
# referencias cruzadas y en el índice de búsqueda.
import os, re, glob, json
out = os.environ.get('QUARTO_PROJECT_OUTPUT_DIR', '_book')
if not os.path.isdir(os.path.join(out, 'chapters')):
    raise SystemExit(0)
files = glob.glob(os.path.join(out, 'chapters', '*.html'))
mapa = {}
cap = re.compile(r'<figcaption[^>]*>\s*(?:Figura|Tabla)&nbsp;(\d+)\.\d+')
for f in files:
    b = os.path.basename(f)
    if not re.match(r'[ab]\d\d-', b):
        continue
    code = b[0].upper() + str(int(b[1:3]))
    for n in cap.findall(open(f, encoding='utf-8').read()):
        mapa.setdefault(n, code)
if not mapa:
    raise SystemExit(0)
def fix(s):
    s = re.sub(r'((?:Figura|Tabla)(?:&nbsp;| | ))(\d+)\.(\d+)',
               lambda m: m.group(1) + mapa.get(m.group(2), m.group(2)) + '.' + m.group(3), s)
    s = re.sub(r'(class="quarto-xref"[^>]*>(?:(?:Figura|Tabla)&nbsp;)?<span>)(\d+)\.(\d+)(</span>)',
               lambda m: m.group(1) + mapa.get(m.group(2), m.group(2)) + '.' + m.group(3) + m.group(4), s)
    return s
n_files = 0
for f in glob.glob(os.path.join(out, '**', '*.html'), recursive=True) + [os.path.join(out, 'search.json')]:
    if not os.path.exists(f):
        continue
    s = open(f, encoding='utf-8').read()
    t = fix(s)
    if t != s:
        open(f, 'w', encoding='utf-8').write(t); n_files += 1
print(f'numeración de figuras: {len(mapa)} temas, {n_files} archivos actualizados')
