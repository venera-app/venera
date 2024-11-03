import re
import json

path='./assets/translation.json'

with open(path, 'r',encoding='utf-8') as file:
  translations=json.load(file)


while True:
  line=input()
  if line=="q":
    break
  words=line.split('-')
  if len(words)!=3:
    print("invalid entry:",line,"(len(words) != 3)"
    continue
  en=words[0]
  cn=words[1]
  tw=words[2]
  translations["zh_CN"][en]=cn
  translations["zh_TW"][en]=tw
  

with open(path, 'w',encoding='utf-8') as file:
    json.dump(translations, file, indent=2,ensure_ascii=False)

  



