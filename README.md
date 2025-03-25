# PromptSynth

## The Narrative

2024 : Testing LLM’s with generating Supercollider Code
Claude 3.5 (June 2024) was the first time code was generated that was successful
Began to test the depth of understanding of generating SC code
Surprisingly successful at different prompt strategies for different outcomes
synth construction
Describing a synth design with parameters
Model a hardware synth (eg. Juno-8, MoogOne, Buchla, ArpOdyssey)
Descriptive (texture, object, environment) Eg:
Metal, wood, Melbourne Pedestrian Crossing
Raindrop, Whip Bird, Forest, Cricket, Cicada, Interactive Wind
Music construction
Steve Reich, Brain Eno, Stockhausen, Xenakis
Vibe coding (Andrej Karpathy in February 2025) : continue to use this in all my synth designs, from building scaffolding code to abstract descriptions.
2025 : The need to automate : Claude’s API. Sign me up!
Built a very basic work flow : evolve synths.
Start with a prototype synth
Give a prompt (used for every iteration) 
Hit go : (calls to SC to load, interpret and play new Synth Definition)
Each iteration is saved and then loaded into SC, so every iteration is archived.




Outcome so far : 
Very successful in creating a family of sounds that evolve over each iteration
Errors propagate but sometimes disappear after several iterations
Feels like I am growing synths
Have not improved or developed the idea further as I am too busy ‘prompting’ new ideas and listening. Is this a good thing?

The Project

Build more robust ‘play ground’ for testing LLM’s and workflows
Looking for collaborators :  ideas, techniques, code
Rag (Retrieval-Augmented Generation), MCP (Model Context Protocol) and tooling.
Archive outputs : code and audio
Big dream : local model running on a RPI or Mac Mini that generates continuous soundscape with prompting (text for now) that guides the composition.

