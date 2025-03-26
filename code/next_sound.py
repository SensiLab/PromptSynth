import anthropic
import re
from pythonosc import udp_client
import time

count = 4
secsPerSynth = 10

ip = "127.0.0.1"
port = 57120
oscClient = udp_client.SimpleUDPClient(ip, port)

client = anthropic.Anthropic()
path = "/Users/soh_la/Develop/Python/Projects/claude/"
name = "template"
index = 0

file_path = 'prompt.sc'
with open(file_path, 'r') as file:
    prompt = file.read()

oscClient.send_message("/start", 0)

while index < count:

  file_path = f'{path}{name}_{index}.sc'
  with open(file_path, 'r') as file:
      supercollider_code = file.read()

  index += 1

  if True:
    message = client.messages.create(
      model="claude-3-5-sonnet-20241022",
      # model="claude-3-7-sonnet-20250219",
      max_tokens=1004,
      temperature=1,
      system="You are a Supercollider expert designed to generate code examples.",
      messages=[
          {
              "role": "user",
              "content": [
                  {
                      "type": "text",
                      "text": prompt
                  },{
                      "type": "text",
                      "text": "```supercollider\n" + supercollider_code + "\n```"
                  }
              ]
          }
      ]
    ) 
    
    text_block = (message.content[0].text)
    print(text_block)
    code_block = re.search(r'```supercollider(.*?)```', text_block, re.DOTALL).group(1).strip()

  else:
    synths = ["WhiteNoise.ar(0.2)","SinOsc.ar(440, 0, 0.2)","Pulse.ar(440, 0.2, 0.2)","Saw.ar(440, 0.2)","LFPulse.ar(440, 0.2)","LFSaw.ar(440, 0.2)","LFPar.ar(440, 0.2)","Blip.ar(440, 0.2)"]
    n = '\synth'
    code_block = f'Ndef({n}).source = '+'{'+f'{synths[index]}'+'})'

  file_path = f'{path}{name}_{index}.sc'
  with open(file_path, 'w') as file:
      file.write(code_block)

  oscClient.send_message("/next", file_path)
  print("sending " + file_path)
  time.sleep(secsPerSynth)

oscClient.send_message("/end", 0)
