# PromptSynth

## The Narrative

Since the launch of LLM's, I've been testing them by trying to generate [Supercollider](https://supercollider.github.io)(SC) Code. Fast forward....
[Claude](https://claude.ai) 3.5 (June 2024) was the first time succesful code was generated. Time to play!
- Began to test the depth of understanding of generating SC code
- Surprisingly successful at different prompt strategies for different outcomes 
    - Synth construction
        - Describing a synth design with parameters
        - Model a hardware synth (eg. Juno-8, MoogOne, Buchla, ArpOdyssey)
        - Descriptive (texture, object, environment) Eg:
Metal, wood, Melbourne Pedestrian Crossing
Raindrop, Whip Bird, Forest, Cricket, Cicada, Interactive Wind

    - Music construction
        - Steve Reich, Brain Eno, Stockhausen, Xenakis

- Vibe coding (ish) ([Andrej Karpathy](https://karpathy.ai)) : continue to use this in all my synth designs, from building scaffolding code to abstract descriptions.
- 2025 : The need to automate : [Claude’s API](https://docs.anthropic.com/en/release-notes/api). $ign me up!
- Hacked a very basic work flow : evolve synths.
    - Start with a prototype synth
    - Give a prompt (used for every iteration) 
    - Hit go : (calls to SC to load, interpret and play new Synth Definition)
    - Each iteration is saved and then loaded into SC, so every iteration is archived.

- Outcome so far : 
    - Very successful in creating a family of sounds that evolve over each iteration
    - Errors propagate but sometimes disappear after several iterations
    - Feels like I am growing synths
    - Have not improved or developed the idea further as I am too busy ‘prompting’ new ideas and listening. Is this a good thing?

- What next...

    - Build more robust ‘play ground’ for testing LLM’s and workflows
    - Rag (Retrieval-Augmented Generation), MCP (Model Context Protocol) and tooling.
    - Archive outputs : code and audio
    - Big dream : local model running on a RPI or Mac 
    - Mini that generates continuous soundscape with prompting (text for now) that guides the composition.
    - Looking for collaborators :  ideas, techniques, code
    
