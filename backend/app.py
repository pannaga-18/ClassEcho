from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware

from fastapi.responses import JSONResponse
import openai
import tempfile
import os
import json
from dotenv import load_dotenv

load_dotenv()
openai.api_key = os.getenv("OPENAI_API_KEY")
print(f"OpenAI API Key Loaded: {openai.api_key is not None}")


app = FastAPI(title="ClassEcho")


# Allow Flutter Web (running in browser) to call backend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # or specify ["http://localhost:8000", "http://127.0.0.1:5500", "http://localhost:1234"]
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
def home():
    print("Home endpoint hit! Debug print works.")
    return {"message": "Welcome to Lecture Voice-to-Notes MVP"}



@app.get("/test-endpoint")
def test():
    print("Test endpoint hit! Debug print works.")
    return {"message": "This is a test endpoint."}




@app.post("/upload-audio")
async def upload_audio(audio: UploadFile = File(...)):
    print(f"Received audio file: {audio.filename}")
    contents = await audio.read()  # just reading bytes for now
    print(f"File size: {len(contents)} bytes")
    # Later: send contents to speech-to-text model
    return {"status": "success", "filename": audio.filename, "size": len(contents)}

from groq import Groq
import tempfile
import os
import json
from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse
import openai

app = FastAPI()

# Initialize clients
openai_client = openai.OpenAI()  # for Whisper (speech-to-text)
groq_client = Groq(api_key=os.environ.get("GROQ_API_KEY"))  # for note generation


from groq import Groq
import tempfile
import os
import json
from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse

app = FastAPI()

# Initialize Groq client
groq_client = Groq(api_key=os.environ.get("GROQ_API_KEY"))


# ==========================================
# OPTION 1: Groq Whisper (FREE & FAST) ✅ RECOMMENDED
# ==========================================
async def speech_to_text_groq(audio_bytes: bytes) -> str:
    """
    Uses Groq's Whisper implementation - FREE and very fast!
    Supports: flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, webm
    Max file size: 25 MB
    """
    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        tmp.write(audio_bytes)
        tmp_path = tmp.name

    with open(tmp_path, "rb") as f:
        transcription = groq_client.audio.transcriptions.create(
            file=f,
            model="whisper-large-v3-turbo",  # or "whisper-large-v3"
            response_format="text",
            language="en",  # optional: specify language
            temperature=0.0
        )

    os.remove(tmp_path)
    return transcription

# ✅ 2. Summarize & Structure Notes (using Groq)
async def summarize_and_structure(text: str) -> dict:
    prompt = f"""
    You are a helpful note-taking assistant. 
    From the following transcript, extract topics, headings, and bullet points.
    Return the result in strict JSON with this format:
    {{
      "title": "Lecture Title",
      "topics": [
        {{"heading": "Topic 1", "points": ["point A", "point B"]}},
        {{"heading": "Topic 2", "points": ["point A", "point B"]}}
      ]
    }}

    Transcript:
    {text}
    """

    response = groq_client.chat.completions.create(
        model="llama-3.3-70b-versatile",  # or "mixtral-8x7b-32768" for longer contexts
        messages=[{"role": "user", "content": prompt}],
        temperature=0.2,
        response_format={"type": "json_object"}  # Groq supports JSON mode
    )

    raw_output = response.choices[0].message.content.strip()

    # Try to parse JSON safely
    try:
        notes = json.loads(raw_output)
    except json.JSONDecodeError:
        # Fallback: try to extract JSON substring
        start = raw_output.find("{")
        end = raw_output.rfind("}") + 1
        json_str = raw_output[start:end]
        notes = json.loads(json_str)

    return notes

# ✅ 3. API Endpoint
@app.post("/process-audio")
async def process_audio(audio: UploadFile = File(...)):
    contents = await audio.read()

    # Step 1: Audio → Transcript
    transcript = await speech_to_text_groq(contents)

    # Step 2: Transcript → Structured Notes (now using Groq)
    structured_notes = await summarize_and_structure(transcript)

    return JSONResponse(content=structured_notes)