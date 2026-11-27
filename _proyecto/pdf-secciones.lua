-- Solo PDF (pensando en la edición impresa): dentro de cada tema, cada sección (##:
-- Introducción, 1, 2, 3, Conclusiones, Anexo) empieza en página nueva. La primera, la Introducción, sigue al título del tema.
-- No afecta a las páginas que no son temas (presentación, notación, bibliografía), ni a la web ni a los guiones.
local en_tema, primera = false, false

local function marcar(bloques)
  local out = pandoc.List()
  for _, b in ipairs(bloques) do
    if b.t == 'Header' and b.level == 1 then
      en_tema = pandoc.utils.stringify(b):match('^[AB]%d+%.%s') ~= nil
      primera = true
    elseif b.t == 'Header' and b.level == 2 and en_tema then
      if primera then
        primera = false
      else
        out:insert(pandoc.RawBlock('latex', '\\clearpage'))
      end
    elseif b.t == 'Div' then
      b.content = marcar(b.content)
    end
    out:insert(b)
  end
  return out
end

function Pandoc(doc)
  doc.blocks = marcar(doc.blocks)
  return doc
end
