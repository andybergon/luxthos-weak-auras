aura_env.CLASS = aura_env.id:gsub("Class Options %- LWA %- ", "")

LWA = LWA or {}
LWA[aura_env.CLASS] = LWA[aura_env.CLASS] or {}

local LWA = LWA[aura_env.CLASS]

LWA.configs = LWA.configs or {}
LWA.configs["class"] = aura_env.config

