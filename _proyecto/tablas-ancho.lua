-- Anchos de columna de las tablas ajustados al contenido y al ancho de la página.
-- Pandoc fija los anchos de una tabla de barras por la longitud de los guiones de la línea separadora
-- (|:--|:--|:--| da tres columnas iguales), lo que deja columnas cortas con mucho blanco.
-- - Web: se quitan esos anchos y el navegador ajusta cada columna a su contenido, a todo el ancho; las columnas
--   cortas de las tablas que no caben en una línea llevan la clase .nowrap para no partirse.
-- - PDF: los anchos se calculan con la longitud del contenido. Las columnas cortas reciben lo justo para ir en
--   una línea y el resto del ancho, hasta el margen, se reparte entre las largas. Las tablas estrechas quedan
--   con anchos naturales.
-- Las tablas con anchos explícitos (tbl-colwidths) y las cuentas en forma de T (.balance) se dejan como están.

local ENVOLTORIOS = { text = true, mathbf = true, mathrm = true, mathit = true, boldsymbol = true, operatorname = true,
  left = true, right = true, big = true, Big = true, bigl = true, bigr = true, displaystyle = true,
  dfrac = true, frac = true, tfrac = true, limits = true }
local function vislen_math(tex)
  -- anchura aproximada en caracteres de una fórmula: los envoltorios (\\text, \\mathbf…) no cuentan, los símbolos
  -- (\\Delta, \\leq…) cuentan uno y los operadores binarios y relaciones llevan espacio a ambos lados
  local s = tex:gsub('\\([a-zA-Z]+)', function(c) return ENVOLTORIOS[c] and '' or 'x' end)
  local ops = select(2, s:gsub('[=<>+%-]', ''))
  s = s:gsub('[{}^_\\ ,]', '')
  return math.max(1, #s + ops)
end

local function measure(blocks)
  -- longitud visible aproximada (caracteres) y palabra más larga de una celda
  local total, longest = 0, 0
  pandoc.walk_block(pandoc.Div(blocks), {
    Str = function(el)
      local n = utf8.len(el.text) or #el.text
      total = total + n
      if n > longest then longest = n end
    end,
    Space = function() total = total + 1 end,
    Math = function(el)
      local n = vislen_math(el.text)
      total = total + n
      if n > longest then longest = n end
    end,
    Code = function(el) total = total + #el.text end,
  })
  return total, longest
end

local function has_explicit_widths(tbl)
  local a = tbl.attr and tbl.attr.attributes or {}
  if a['tbl-colwidths'] then return true end
  local cap = pandoc.utils.stringify(tbl.caption and tbl.caption.long or {})
  -- en este punto los atributos de la tabla siguen en el texto del pie: {#tbl-… .clase tbl-colwidths="…"}
  -- las cuentas en forma de T (.balance) conservan sus dos mitades iguales
  return cap:find('tbl%-colwidths') ~= nil or cap:find('%.balance') ~= nil
end

local function plan(tbl)
  -- devuelve las fracciones de ancho de cada columna (o nil si la tabla cabe holgada) y las columnas cortas
  local n = #tbl.colspecs
  local need, minw = {}, {}
  for j = 1, n do need[j], minw[j] = 1, 1 end
  local function scan(rows)
    for _, row in ipairs(rows) do
      local j = 1
      for _, cell in ipairs(row.cells) do
        local span = cell.col_span or 1
        if span == 1 and j <= n then
          local t, w = measure(cell.contents)
          if t > need[j] then need[j] = t end
          if w > minw[j] then minw[j] = w end
        end
        j = j + span
      end
    end
  end
  scan(tbl.head.rows)
  for _, body in ipairs(tbl.bodies) do scan(body.head); scan(body.body) end
  scan(tbl.foot.rows)
  -- presupuesto de caracteres en una línea de texto (unos 98 en el PDF), descontado el relleno entre columnas
  local budget = 96 - 2.5 * n
  local sum = 0
  for j = 1, n do sum = sum + need[j] end
  if sum <= budget * 0.55 then return nil, {} end  -- tabla estrecha: anchos naturales, nada se parte
  local alloc, short = {}, {}
  if sum <= budget then
    for j = 1, n do alloc[j] = need[j] end         -- todo cabe en una línea: se estira hasta el margen
  else
    -- columnas cortas (las que no pasan de su parte igual de la línea ni del 30 %) en una sola línea,
    -- mientras no ocupen más del 60 %
    local idx = {}
    for j = 1, n do idx[#idx + 1] = j end
    table.sort(idx, function(a, b) return need[a] < need[b] end)
    local used = 0
    for _, j in ipairs(idx) do
      if need[j] <= math.min(0.3 * budget, budget / n) and used + need[j] <= 0.6 * budget and #idx > 1 then
        short[j] = true; alloc[j] = need[j] * 1.08 + 1.5; used = used + alloc[j]  -- holgura: la letra varía
      end
    end
    -- columnas largas: reparto según la raíz de su longitud (una columna muy larga no ahoga a las medianas),
    -- sin dar a ninguna más de lo que necesita ni menos que su palabra o fórmula más larga
    local rem = budget - used
    local open = {}
    for j = 1, n do if not short[j] then open[j] = true end end
    local changed = true
    while changed do
      changed = false
      local wsum = 0
      for j in pairs(open) do wsum = wsum + math.sqrt(need[j]) end
      for j in pairs(open) do
        local share = rem * math.sqrt(need[j]) / wsum
        if share >= need[j] then
          alloc[j] = need[j]; rem = rem - need[j]; open[j] = nil; changed = true
        end
      end
    end
    local wsum = 0
    for j in pairs(open) do wsum = wsum + math.sqrt(need[j]) end
    for j in pairs(open) do
      alloc[j] = math.max(minw[j] + 1, math.min(need[j], 0.18 * budget), rem * math.sqrt(need[j]) / wsum)
    end
  end
  local tot = 0
  for j = 1, n do tot = tot + alloc[j] end
  local out = {}
  for j = 1, n do out[j] = alloc[j] / tot end
  if os.getenv('TABLAS_INFORME') then  -- informe para revisar los anchos: TABLAS_INFORME=1
    local cap = pandoc.utils.stringify(tbl.caption and tbl.caption.long or {}):sub(1, 50)
    local parts = {}
    for j = 1, n do parts[#parts + 1] = string.format('%s%d:%.0f%%', short[j] and '*' or '', need[j], 100 * out[j]) end
    io.stderr:write(string.format('TABLA %s | %s\n', cap, table.concat(parts, ' ')))
  end
  return out, short
end

local function mark_nowrap(tbl, short)
  local function mark(rows)
    for _, row in ipairs(rows) do
      local j = 1
      for _, cell in ipairs(row.cells) do
        if short[j] and (cell.col_span or 1) == 1 then
          cell.attr.classes:insert('nowrap')
        end
        j = j + (cell.col_span or 1)
      end
    end
  end
  mark(tbl.head.rows)
  for _, body in ipairs(tbl.bodies) do mark(body.head); mark(body.body) end
  mark(tbl.foot.rows)
end

function Table(tbl)
  if has_explicit_widths(tbl) then return nil end
  local latex = FORMAT:match('latex') or FORMAT:match('pdf')
  local widths, short = plan(tbl)
  if not latex then
    widths = nil                  -- en la web, anchos del navegador (mide la letra real)
    mark_nowrap(tbl, short)       -- y las columnas cortas, sin partir (regla .nowrap de styles.css)
  end
  for j, spec in ipairs(tbl.colspecs) do
    tbl.colspecs[j] = { spec[1], widths and widths[j] or nil }
  end
  return tbl
end
