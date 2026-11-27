-- Filtro solo para PDF (referenciado desde _quarto-pdf.yml).
-- Dentro de un div de figura cruzada (::: {#fig-...}), la imagen estática
-- de la rama PDF lleva su propio pie, lo que produce una figura anidada
-- dentro de otra figura ("Not in outer par mode" en LaTeX). Aquí se
-- elimina ese pie interno: el pie de la figura es el párrafo final del div.

-- En el PDF, los gráficos de un panel se imprimen al 72 % del ancho del texto y los de
-- varios paneles (marco «graph-frame wide» en la versión web) a todo el ancho. Los nombres de los anchos se leen del
-- propio capítulo; se respeta un ancho fijado a mano.
local anchos = nil
local function cargar_anchos()
  anchos = {}
  for _, f in ipairs(PANDOC_STATE.input_files or {}) do
    local h = io.open(f, 'r')
    if h then
      local t = h:read('a'); h:close()
      for nombre in t:gmatch('graph%-frame wide">%s*<iframe src="%.%./graphs/([^"/]+)%.html') do anchos[nombre] = true end
    end
  end
end

-- Un gráfico de un panel más ancho que el estándar (viewBox de 680) se imprime en proporción (p. ej. 780 → 83 %),
-- para que su letra salga del mismo tamaño que la de los demás.
local function base_svg(nombre)
  local h = io.open('graphs/' .. nombre .. '.html', 'r')
  if not h then return 680 end
  local t = h:read('a'); h:close()
  local w = t:match('<svg[^>]-viewBox="%s*[-%d.]+[%s,]+[-%d.]+[%s,]+([%d.]+)')
  return tonumber(w) or 680
end

local function ancho(img)
  if anchos == nil then cargar_anchos() end
  local nombre = img.src:match('graphs/static/([^/]+)%.png$')
  if nombre and not anchos[nombre] and not img.attributes.width then
    img.attributes.width = string.format('%d%%', math.min(100, math.floor(72 * base_svg(nombre) / 680 + 0.5)))
  end
  return img
end

local function strip(blocks)
  return pandoc.Blocks(blocks):walk({
    Figure = function(fig)
      local imgs = {}
      pandoc.walk_block(fig, {
        Image = function(img)
          img.caption = {}
          table.insert(imgs, ancho(img))
        end
      })
      if #imgs > 0 then
        return pandoc.Plain(imgs)
      end
    end,
    Image = function(img)
      img.caption = {}
      img.title = ""
      return ancho(img)
    end
  })
end

return {
  {
    -- Quarto convierte ::: {#fig-...} en un nodo FloatRefTarget antes de
    -- los filtros de usuario; se captura aquí.
    FloatRefTarget = function(float)
      if float.type == "Figure" and float.content then
        float.content = strip(float.content)
        return float
      end
    end,
    Div = function(div)
      if div.identifier:match("^fig%-") then
        div.content = strip(div.content)
        return div
      end
    end
  }
}
