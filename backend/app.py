# from fastapi import FastAPI, UploadFile, File
# from fastapi.middleware.cors import CORSMiddleware

# from fastapi.responses import JSONResponse
# import openai
# import tempfile
# import os
# import json
# from dotenv import load_dotenv
# from groq import Groq


# # Load environment variables from .env file
# load_dotenv()



# app = FastAPI(title="ClassEcho")


# # Allow Flutter Web (running in browser) to call backend
# app.add_middleware(
#     CORSMiddleware,
#     allow_origins=["*"],  # or specify ["http://localhost:8000", "http://127.0.0.1:5500", "http://localhost:1234"]
#     allow_credentials=True,
#     allow_methods=["*"],
#     allow_headers=["*"],
# )

# @app.get("/")
# def home():
#     print("Home endpoint hit! Debug print works.")
#     return {"message": "Welcome to Lecture Voice-to-Notes MVP"}



# @app.get("/test-endpoint")
# def test():
#     print("Test endpoint hit! Debug print works.")
#     return {"message": "This is a test endpoint."}




# @app.post("/upload-audio")
# async def upload_audio(audio: UploadFile = File(...)):
#     print(f"Received audio file: {audio.filename}")
#     contents = await audio.read()  # just reading bytes for now
#     print(f"File size: {len(contents)} bytes")
#     # Later: send contents to speech-to-text model
#     return {"status": "success", "filename": audio.filename, "size": len(contents)}




# # Initialize clients
# groq_client = Groq(api_key=os.environ.get("GROQ_API_KEY"))  # for note generation
# print(f"Groq API Key Loaded: {os.environ.get('GROQ_API_KEY') is not None}")




# # ==========================================
# # OPTION 1: Groq Whisper (FREE & FAST) ✅ RECOMMENDED
# # ==========================================
# async def speech_to_text_groq(audio_bytes: bytes) -> str:
#     """
#     Uses Groq's Whisper implementation - FREE and very fast!
#     Supports: flac, mp3, mp4, mpeg, mpga, m4a, ogg, wav, webm
#     Max file size: 25 MB
#     """
#     with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
#         tmp.write(audio_bytes)
#         tmp_path = tmp.name

#     with open(tmp_path, "rb") as f:
#         transcription = groq_client.audio.transcriptions.create(
#             file=f,
#             model="whisper-large-v3-turbo",  # or "whisper-large-v3"
#             response_format="text",
#             language="en",  # optional: specify language
#             temperature=0.0
#         )

#     os.remove(tmp_path)
#     return transcription

# # ✅ 2. Summarize & Structure Notes (using Groq)
# async def summarize_and_structure(text: str) -> dict:
#     prompt = f"""
# You are an expert note-taking assistant and learning guide. Your task is to transform the following transcript into comprehensive, actionable study notes.

# **Instructions:**
# 1. Identify and extract all speakers (if mentioned) and attribute their contributions
# 2. Organize content into clear topics with descriptive headings
# 3. For each topic, provide:
#    - Key points with detailed explanations
#    - Context and additional insights to deepen understanding
#    - Practical examples or applications
#    - Recommended learning resources (books, courses, articles, or tools)
#    - Summary that connects ideas together
# 4. Act as a learning guide by highlighting important concepts and suggesting next steps

# Return the result in strict JSON with this exact format:
# {{
#   "title": "Descriptive Title of the Lecture/Discussion",
#   "overview": "Brief 2-3 sentence overview of the entire content",
#   "speakers": [
#     {{
#       "name": "Speaker Name or 'Unknown' if not mentioned",
#       "role": "Their role or context if mentioned",
#       "key_contributions": ["Main points they discussed"]
#     }}
#   ],
#   "topics": [
#     {{
#       "heading": "Clear Topic Heading",
#       "summary": "2-3 sentence summary of this topic",
#       "key_points": [
#         {{
#           "point": "Main point statement",
#           "explanation": "Detailed explanation with context",
#           "examples": ["Practical example 1", "Practical example 2"],
#           "importance": "Why this matters or how to apply it"
#         }}
#       ],
#       "additional_insights": [
#         "Extra context or connection to other concepts",
#         "Common misconceptions or pitfalls to avoid"
#       ],
#       "recommended_resources": [
#         {{
#           "type": "book|course|article|video|tool|documentation",
#           "title": "Resource name",
#           "description": "Why this resource is helpful",
#           "url": "URL if applicable or 'Search online'"
#         }}
#       ]
#     }}
#   ],
#   "key_takeaways": [
#     "Most important insight 1",
#     "Most important insight 2",
#     "Most important insight 3"
#   ],
#   "action_items": [
#     "Specific next step or practice exercise 1",
#     "Specific next step or practice exercise 2"
#   ],
#   "further_learning": {{
#     "beginner": ["Resource for those new to the topic"],
#     "intermediate": ["Resource for those with some knowledge"],
#     "advanced": ["Resource for deep diving"]
#   }}
# }}

# **Transcript:**
# {text}

# **Important:** 
# - If speakers are not identified in the transcript, use "Speaker 1", "Speaker 2" or "Unknown Speaker"
# - Ensure all JSON is properly formatted with correct escaping
# - Provide specific, actionable resource recommendations
# - Keep summaries concise but informative
# - Focus on creating value beyond just transcribing - add insights that help learning
# """
    
#     response = groq_client.chat.completions.create(
#         model="llama-3.3-70b-versatile",
#         messages=[{"role": "user", "content": prompt}],
#         temperature=0.2,
#         response_format={"type": "json_object"}
#     )

#     raw_output = response.choices[0].message.content.strip()

#     try:
#         notes = json.loads(raw_output)
#     except json.JSONDecodeError:
#         start = raw_output.find("{")
#         end = raw_output.rfind("}") + 1
#         json_str = raw_output[start:end]
#         notes = json.loads(json_str)

#     return notes


# # ✅ 3. API Endpoint
# @app.post("/process-audio")
# async def process_audio(audio: UploadFile = File(...)):
#     contents = await audio.read()

#     # Step 1: Audio → Transcript
#     transcript = await speech_to_text_groq(contents)

#     # Step 2: Transcript → Structured Notes (now using Groq)
#     structured_notes = await summarize_and_structure(transcript)

#     return JSONResponse(content=structured_notes)





from fastapi import FastAPI, UploadFile, File, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import tempfile
import os
import json
from dotenv import load_dotenv
from groq import Groq
from groq import RateLimitError, APIError
import logging

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Load environment variables
load_dotenv()

app = FastAPI(title="ClassEcho")

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==========================================
# GROQ API KEY ROTATION MANAGER
# ==========================================
class GroqKeyManager:
    def __init__(self):
        # Load all available API keys from environment
        self.api_keys = []
        self.current_key_index = 0
        
        # Load keys in order: GROQ_API_KEY, GROQ_API_KEY1, GROQ_API_KEY2, etc.
        base_key = os.environ.get("GROQ_API_KEY")
        if base_key:
            self.api_keys.append(base_key)
            logger.info(f"Loaded GROQ_API_KEY")
        
        # Load numbered keys
        i = 1
        while True:
            key = os.environ.get(f"GROQ_API_KEY{i}")
            if key:
                self.api_keys.append(key)
                logger.info(f"Loaded GROQ_API_KEY{i}")
                i += 1
            else:
                break
        
        if not self.api_keys:
            raise ValueError("No Groq API keys found in environment variables!")
        
        logger.info(f"Total API keys loaded: {len(self.api_keys)}")
        
        # Initialize client with first key
        self.client = Groq(api_key=self.api_keys[self.current_key_index])
    
    def get_client(self):
        """Get current Groq client"""
        return self.client
    
    def rotate_key(self):
        """Rotate to next available API key"""
        if len(self.api_keys) <= 1:
            logger.error("No backup keys available!")
            raise HTTPException(
                status_code=503,
                detail="All API keys exhausted. Please try again later."
            )
        
        self.current_key_index = (self.current_key_index + 1) % len(self.api_keys)
        self.client = Groq(api_key=self.api_keys[self.current_key_index])
        logger.warning(f"Rotated to API key #{self.current_key_index + 1}")
        return self.client
    
    async def execute_with_retry(self, func, *args, max_retries=None, **kwargs):
        """
        Execute a function with automatic key rotation on rate limit
        
        Args:
            func: The function to execute
            max_retries: Maximum number of key rotations (default: number of keys)
            *args, **kwargs: Arguments to pass to the function
        """
        if max_retries is None:
            max_retries = len(self.api_keys)
        
        last_error = None
        
        for attempt in range(max_retries):
            try:
                # Execute the function with current client
                result = await func(self.get_client(), *args, **kwargs)
                return result
                
            except RateLimitError as e:
                last_error = e
                logger.warning(f"Rate limit hit on key #{self.current_key_index + 1}: {str(e)}")
                
                if attempt < max_retries - 1:
                    # Rotate to next key
                    self.rotate_key()
                    logger.info(f"Retrying with key #{self.current_key_index + 1}...")
                else:
                    logger.error("All API keys exhausted!")
                    
            except APIError as e:
                # For other API errors, don't retry
                logger.error(f"API Error: {str(e)}")
                raise HTTPException(status_code=500, detail=f"API Error: {str(e)}")
            
            except Exception as e:
                logger.error(f"Unexpected error: {str(e)}")
                raise HTTPException(status_code=500, detail=f"Error: {str(e)}")
        
        # If we exhausted all retries
        raise HTTPException(
            status_code=429,
            detail=f"All {len(self.api_keys)} API keys are rate limited. Please try again later."
        )

# Initialize key manager
key_manager = GroqKeyManager()

# ==========================================
# ENDPOINTS
# ==========================================

@app.get("/")
def home():
    return {
        "message": "Welcome to ClassEcho API",
        "available_keys": len(key_manager.api_keys),
        "current_key": key_manager.current_key_index + 1
    }

@app.get("/api-status")
def api_status():
    """Check API key status"""
    return {
        "total_keys": len(key_manager.api_keys),
        "current_key_index": key_manager.current_key_index + 1,
        "keys_remaining": len(key_manager.api_keys) - key_manager.current_key_index
    }

# ==========================================
# SPEECH TO TEXT WITH KEY ROTATION
# ==========================================
async def speech_to_text_groq(client: Groq, audio_bytes: bytes) -> str:
    """
    Uses Groq's Whisper implementation with provided client
    """
    with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as tmp:
        tmp.write(audio_bytes)
        tmp_path = tmp.name

    try:
        with open(tmp_path, "rb") as f:
            transcription = client.audio.transcriptions.create(
                file=f,
                model="whisper-large-v3-turbo",
                response_format="text",
                language="en",
                temperature=0.0
            )
        return transcription
    finally:
        os.remove(tmp_path)


# ==========================================
# SUMMARIZE WITH KEY ROTATION
# ==========================================
async def summarize_and_structure(client: Groq, text: str) -> dict:
    """
    Generate structured notes using provided Groq client
    """
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
    
    response = client.chat.completions.create(
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


# ==========================================
# Q&A GENERATION FUNCTION
# ==========================================
async def generate_questions_and_answers(client: Groq, text: str) -> dict:
    """
    Generate comprehensive Q&A based on the transcript
    Returns 20 most relevant questions with detailed answers
    """
    prompt = f"""
You are an expert educator and question generator. Your task is to create comprehensive, thoughtful questions and answers based on the following transcript to help students test their understanding and reinforce learning.

**Instructions:**
1. Analyze the transcript thoroughly
2. Generate exactly 20 questions that cover:
   - Key concepts and definitions (5 questions)
   - Application and practical scenarios (5 questions)
   - Critical thinking and analysis (5 questions)
   - Synthesis and connections (5 questions)
3. Each question should:
   - Be clear and specific
   - Test real understanding, not just memorization
   - Be answerable from the content provided
   - Progress from basic to advanced difficulty
4. Each answer should:
   - Be comprehensive yet concise
   - Include examples where relevant
   - Explain the "why" not just the "what"
   - Connect to broader concepts when applicable

Return the result in strict JSON with this exact format:
{{
  "topic": "Main topic of the transcript",
  "total_questions": 20,
  "difficulty_breakdown": {{
    "easy": 5,
    "medium": 10,
    "hard": 5
  }},
  "questions": [
    {{
      "id": 1,
      "question": "Clear, specific question text",
      "answer": "Comprehensive answer with explanation",
      "difficulty": "easy|medium|hard",
      "category": "concept|application|critical_thinking|synthesis",
      "key_terms": ["term1", "term2"],
      "related_topics": ["topic1", "topic2"]
    }}
  ],
  "study_tips": [
    "Tip 1 for effective studying",
    "Tip 2 for retention",
    "Tip 3 for application"
  ],
  "quiz_summary": {{
    "main_themes": ["theme1", "theme2", "theme3"],
    "prerequisites": ["What students should know before"],
    "next_steps": ["What to study next"]
  }}
}}

**Transcript:**
{text}

**Important:** 
- Generate EXACTLY 20 questions
- Ensure questions are diverse in type and difficulty
- Answers should be 2-4 sentences each
- Focus on understanding, not trivia
- Make questions practical and relevant
"""
    
    response = client.chat.completions.create(
        model="llama-3.3-70b-versatile",
        messages=[{"role": "user", "content": prompt}],
        temperature=0.3,  # Slightly higher for more diverse questions
        response_format={"type": "json_object"}
    )

    raw_output = response.choices[0].message.content.strip()

    try:
        qa_data = json.loads(raw_output)
    except json.JSONDecodeError:
        start = raw_output.find("{")
        end = raw_output.rfind("}") + 1
        json_str = raw_output[start:end]
        qa_data = json.loads(json_str)

    print(qa_data)
    print("Length of Q&A data:", len(qa_data.get("questions", [])))
    return qa_data



# ==========================================
# MAIN ENDPOINT WITH AUTOMATIC KEY ROTATION
# ==========================================

@app.post("/generate_qa")
async def generate_qa_endpoint(audio: UploadFile = File(...)):
    """
    Generate Q&A only from audio
    """
    try:
        contents = await audio.read()
        
        # Transcribe
        transcript = await key_manager.execute_with_retry(
            speech_to_text_groq,
            contents
        )
        
        # Generate Q&A
        qa_data = await key_manager.execute_with_retry(
            generate_questions_and_answers,
            transcript
        )
        
        return JSONResponse(content=qa_data)
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))



@app.post("/generate_notes")
async def generate_notes(audio: UploadFile = File(...)):
    """
    Process audio file with automatic API key rotation on rate limits
    """
    try:
        contents = await audio.read()
        logger.info(f"Processing audio file: {audio.filename} ({len(contents)} bytes)")

        # Step 1: Audio → Transcript (with automatic key rotation)
        transcript = await key_manager.execute_with_retry(
            speech_to_text_groq,
            contents
        )
        
        logger.info(f"Transcription successful. Length: {len(transcript)} characters")

        
        # Step 2: Transcript → Structured Notes (with automatic key rotation)
        structured_notes = await key_manager.execute_with_retry(
            summarize_and_structure,
            transcript
        )
        
        logger.info("Note generation successful")

        # Add metadata about which key was used
        structured_notes["_metadata"] = {
            "processed_with_key": key_manager.current_key_index + 1,
            "total_keys_available": len(key_manager.api_keys)
        }

        return JSONResponse(content=structured_notes)
    
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Unexpected error in process_audio: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
    



# ==========================================
# ALTERNATIVE: Manual key rotation endpoint
# ==========================================
@app.post("/rotate-key")
def manual_rotate_key():
    """Manually rotate to next API key"""
    try:
        key_manager.rotate_key()
        return {
            "message": "Key rotated successfully",
            "current_key": key_manager.current_key_index + 1,
            "total_keys": len(key_manager.api_keys)
        }
    except HTTPException as e:
        raise e