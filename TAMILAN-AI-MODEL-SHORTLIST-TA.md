# TAMILAN AI — மாடல் shortlist மற்றும் உரிம ஆய்வு (19-11-2026)

## முடிவு சுருக்கம்

**முதல் இலவச prototype-க்கான முதன்மை வேட்பாளர்: அதிகாரப்பூர்வ Qwen/Qwen3-1.7B instruct checkpoint.**

இது இறுதி production model தேர்வு அல்ல. இது குறைந்த வள prototype-க்கு ஏற்ற முதல் candidate மட்டுமே. தமிழ் தரம், job-domain துல்லியம், பாதுகாப்பு, memory மற்றும் latency ஆகியவை நமது test suite மூலம் சோதிக்கப்பட வேண்டும்.

## அதிகாரப்பூர்வ model card ஆய்வு

| மாடல் | அதிகாரப்பூர்வ ஆதாரத்தில் காணப்பட்டது | TAMILAN CAREERS முடிவு |
|---|---|---|
| Qwen/Qwen3-1.7B | Hugging Face model card-ல் Apache-2.0; 1.7B parameters; 100+ மொழிகள்/வழக்குமொழிகள் ஆதரவு எனக் குறிப்பிடுகிறது | முதன்மை prototype candidate. Checkpoint LICENSE-ஐ download/deploy முன் மீண்டும் சரிபார்க்க வேண்டும் |
| Qwen/Qwen3-4B | Hugging Face model card-ல் Apache-2.0; 4B parameters; 100+ மொழிகள்/வழக்குமொழிகள் | தரம் மேம்படுகிறதா என இரண்டாம் candidate; hosting வளம் அதிகம் தேவைப்படலாம் |
| Google Gemma 3 1B | அதிகாரப்பூர்வ ஆவணம் 140+ மொழி பயிற்சி தரவு எனக் கூறுகிறது; தனியான Gemma Terms of Use பொருந்தும் | ஒப்பீட்டு candidate மட்டும்; பயன்பாட்டு விதிமுறைகள் மற்றும் job/employment பயன்பாட்டுக்கான அனுமதி சட்ட/உரிம ஆய்வுக்குப் பிறகே |
| Qualcomm Qwen3-4B package | Qualcomm வெளியிட்ட model card-ல் “education and vocational training” மற்றும் “employment and workers management” தொடர்பான பயன்பாடுகளுக்கு தடை பட்டியலிடப்பட்டுள்ளது | **பயன்படுத்த வேண்டாம்.** அதே பெயருள்ள upstream Qwen மாடலின் உரிமத்துடன் இதை குழப்பக்கூடாது |

## ஆதார இணைப்புகள்

1. Qwen3-1.7B அதிகாரப்பூர்வ model card: https://huggingface.co/Qwen/Qwen3-1.7B
2. Qwen3-1.7B LICENSE: https://huggingface.co/Qwen/Qwen3-1.7B/blob/main/LICENSE
3. Qwen3-4B அதிகாரப்பூர்வ model card: https://huggingface.co/Qwen/Qwen3-4B
4. Gemma 3 அதிகாரப்பூர்வ model card மற்றும் Terms: https://gemma.ai/models/gemma-3/
5. Qualcomm Qwen3-4B பயன்பாட்டு வரம்புகள்: https://huggingface.co/qualcomm/Qwen3-4B

## ஏன் Qwen3-1.7B முதலில்?

- சிறிய அளவு candidate என்பதால் prototype வளத் தேவையை முதலில் அளவிட முடியும்.
- அதிகாரப்பூர்வ model card Apache-2.0 எனக் காட்டுகிறது; இது பொதுவாக commercial use-ஐ அனுமதிக்கும் permissive licence. இருந்தாலும் குறிப்பிட்ட checkpoint-இன் LICENSE, notices மற்றும் applicable laws-ஐ deploy முன் சரிபார்க்க வேண்டும்.
- multilingual capability இருப்பதாக model card கூறுகிறது; ஆனால் தமிழ் உட்பட ஒவ்வொரு மொழிக்கும் நமது test prompts-ல் உண்மையான தரத்தை அளவிட வேண்டும்.
- 1.7B என்பதால் 8 GB Android phone-ல் 24/7 server ஆக இயங்கும் என்று பொருளல்ல. Phone-ல் model host செய்யத் திட்டமில்லை.

## உரிமம் மற்றும் பாதுகாப்பு விதிகள்

- Upstream Qwen repository-இன் உரிமத்தை மட்டுமே மதிப்பிட வேண்டும்; மூன்றாம் தரப்பு quantization/port/package-களுக்கு வேறு விதிமுறைகள் இருக்கலாம்.
- Model weights அல்லது credentials-ஐ GitHub-ல் commit செய்யக்கூடாது.
- User resume அல்லது தனிப்பட்ட தகவலை fine-tuning/training-க்கு consent இல்லாமல் பயன்படுத்தக்கூடாது.
- AI-க்கு வேலை வெளியிடுதல், நிறுவனம் verify செய்தல், விண்ணப்பதாரரை reject செய்தல் போன்ற அதிகாரங்கள் கிடையாது.
- Verified job retrieval மற்றும் source citation இல்லாமல் live vacancy எண்ணிக்கை/வேலை விவரம் உருவாக்கக்கூடாது.

## இன்னும் நிரூபிக்கப்படாதவை

- தமிழ் பதில்களின் தரம் மற்றும் உண்மைத் துல்லியம்
- எல்லா சோதனை மொழிகளிலும் பதில் தரம்
- quantized model memory/latency
- இலவச inference host-இன் தொடர்ச்சியான uptime
- TAMILAN CAREERS-க்கு production-scale செலவு

**தற்போதைய நிலை:** Qwen3-1.7B முதன்மை prototype candidate எனத் தேர்வு செய்யப்பட்டுள்ளது; மாடல் பதிவிறக்கம், இயக்கம், benchmark அல்லது production deployment இன்னும் செய்யப்படவில்லை.
