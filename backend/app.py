from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware

from fastapi.responses import JSONResponse
import openai
import tempfile
import os
import json
from dotenv import load_dotenv
from groq import Groq


# Load environment variables from .env file
load_dotenv()



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




# Initialize clients
groq_client = Groq(api_key=os.environ.get("GROQ_API_KEY"))  # for note generation
print(f"Groq API Key Loaded: {os.environ.get('GROQ_API_KEY') is not None}")




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
You are an expert note-taking assistant and learning guide. Your task is to transform the following transcript into comprehensive, actionable study notes.

**Instructions:**
1. Identify and extract all speakers (if mentioned) and attribute their contributions
2. Organize content into clear topics with descriptive headings
3. For each topic, provide:
   - Key points with detailed explanations
   - Context and additional insights to deepen understanding
   - Practical examples or applications
   - Recommended learning resources (books, courses, articles, or tools)
   - Summary that connects ideas together
4. Act as a learning guide by highlighting important concepts and suggesting next steps

Return the result in strict JSON with this exact format:
{{
  "title": "Descriptive Title of the Lecture/Discussion",
  "overview": "Brief 2-3 sentence overview of the entire content",
  "speakers": [
    {{
      "name": "Speaker Name or 'Unknown' if not mentioned",
      "role": "Their role or context if mentioned",
      "key_contributions": ["Main points they discussed"]
    }}
  ],
  "topics": [
    {{
      "heading": "Clear Topic Heading",
      "summary": "2-3 sentence summary of this topic",
      "key_points": [
        {{
          "point": "Main point statement",
          "explanation": "Detailed explanation with context",
          "examples": ["Practical example 1", "Practical example 2"],
          "importance": "Why this matters or how to apply it"
        }}
      ],
      "additional_insights": [
        "Extra context or connection to other concepts",
        "Common misconceptions or pitfalls to avoid"
      ],
      "recommended_resources": [
        {{
          "type": "book|course|article|video|tool|documentation",
          "title": "Resource name",
          "description": "Why this resource is helpful",
          "url": "URL if applicable or 'Search online'"
        }}
      ]
    }}
  ],
  "key_takeaways": [
    "Most important insight 1",
    "Most important insight 2",
    "Most important insight 3"
  ],
  "action_items": [
    "Specific next step or practice exercise 1",
    "Specific next step or practice exercise 2"
  ],
  "further_learning": {{
    "beginner": ["Resource for those new to the topic"],
    "intermediate": ["Resource for those with some knowledge"],
    "advanced": ["Resource for deep diving"]
  }}
}}

**Transcript:**
{text}

**Important:** 
- If speakers are not identified in the transcript, use "Speaker 1", "Speaker 2" or "Unknown Speaker"
- Ensure all JSON is properly formatted with correct escaping
- Provide specific, actionable resource recommendations
- Keep summaries concise but informative
- Focus on creating value beyond just transcribing - add insights that help learning
"""
    
    response = groq_client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.2,
        response_format={"type": "json_object"}
    )

    raw_output = response.choices[0].message.content.strip()

    try:
        notes = json.loads(raw_output)
    except json.JSONDecodeError:
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