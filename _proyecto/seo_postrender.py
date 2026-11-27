#!/usr/bin/env python3
"""Tras el render: limpia el título de las etiquetas citation_title (Quarto deja “[Título]{.chapter-title}”)
y añade a cada página su dirección canónica (<link rel="canonical">) con el site-url de _quarto.yml, para que los buscadores
indexen una sola dirección por página (la del dominio, no la de github.io ni la terminada en index.html)."""
import os, pathlib, re
out = pathlib.Path(os.environ.get("QUARTO_PROJECT_OUTPUT_DIR", "_book"))
m = re.search(r"^\s*site-url:\s*(\S+)\s*$", pathlib.Path("_quarto.yml").read_text(encoding="utf-8"), re.M)
sitio = m.group(1).rstrip("/") if m else ""
n = c = 0
for p in out.rglob("*.html"):
    rel = p.relative_to(out).as_posix()
    if rel.startswith(("site_libs/", "graphs/")):
        continue
    t = p.read_text(encoding="utf-8")
    t2 = re.sub(r'(<meta name="citation_title" content=")\[(.*?)\]\{\.chapter-title\}(")', r"\1\2\3", t)
    if t2 != t:
        n += 1
    if sitio and 'rel="canonical"' not in t2 and "</head>" in t2:
        url = sitio + "/" + (rel[:-len("index.html")] if rel.endswith("index.html") else rel)
        t2 = t2.replace("</head>", '<link rel="canonical" href="%s">\n</head>' % url, 1); c += 1
    if t2 != t:
        p.write_text(t2, encoding="utf-8")
# El mapa del sitio, con la misma dirección canónica para la portada (…/ en lugar de …/index.html).
sm = out / "sitemap.xml"
if sitio and sm.exists():
    s = sm.read_text(encoding="utf-8"); s2 = s.replace("<loc>%s/index.html</loc>" % sitio, "<loc>%s/</loc>" % sitio)
    if s2 != s:
        sm.write_text(s2, encoding="utf-8")
print(f"seo_postrender: {n} páginas con citation_title limpio, {c} con dirección canónica")
