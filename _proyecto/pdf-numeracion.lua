-- Solo PDF: numera figuras y tablas con el código del tema («Figura A36.1»)
-- en lugar del ordinal del capítulo en el libro («Figura 35.1»).
function Header(h)
  if h.level == 1 then
    local code = pandoc.utils.stringify(h):match("^([AB]%d+)%.%s")
    if code then
      return { h, pandoc.RawBlock("latex", "\\renewcommand{\\thefigure}{" .. code .. ".\\arabic{figure}}\\renewcommand{\\thetable}{" .. code .. ".\\arabic{table}}") }
    end
  end
end
