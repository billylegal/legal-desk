-- Mac-style window animations (Legal Dock): windows spring open with a slight overshoot, shrink-and-fade when closed,
-- and minimized windows slide down toward the dock. Delete this block to go back to Omarchy's defaults.
hl.curve("macSpring", { type = "bezier", points = { { 0.34, 1.45 }, { 0.64, 1 } } })
hl.curve("macEase", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1 } } })
hl.curve("macClose", { type = "bezier", points = { { 0.4, 0 }, { 0.8, 0.4 } } })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 5, bezier = "macSpring", style = "popin 72%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3.2, bezier = "macClose", style = "popin 78%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "macEase" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 3.5, bezier = "macEase" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 3, bezier = "macEase" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "macEase", style = "slidefadevert 35%" })
