local Time = require "socket".gettime

local citations = {
  [[
    - I've walked a white line my entire life, I'm not about to screw that up.
    - White line's in the middle of the road, that's the worst place to drive.
  ]],
  [[
    Life's a bitch, and she's back in heat!
  ]],
  [[
    I have come here to chew bubblegum and kick ass. And I'm all out of bubblegum.
  ]],
  [[
    The Golden Rule: He who has the gold, makes the rules.
  ]],
  [[
    I don't like this one bit. Not one bit.
  ]],
  [[
    Wooo. It's like a drug. Wearing these glasses gets you high, but you come down hard.
  ]],
  [[
    You see, I take these glasses off, she looks like a regular person... on: formaldehyde face.
  ]],
  [[
    You, you're ok. This one, real f***in' ugly.
  ]],
  [[
    You... you look like your face fell in the cheese dip back in 1956.
  ]],
  [[
    Outside the limit of our sight, feeding off us, perched on top of us, from birth to death, are our owners! Our owners! They have us. They control us! They are our masters! Wake up! They're all about you! All around you!
  ]],
  [[
    The world needs a wake up call gentlemen... we're gonna phone it in.
  ]],
  [[
    We could be pets, we could be food, but all we really are is livestock.
  ]],
}

math.randomseed (Time ())

return function ()
  local citation = citations [math.random (#citations)]
  return citation
end
