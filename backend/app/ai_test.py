import os, json
from openai import OpenAI

client = OpenAI()
MODEL = os.getenv("ASSESSMENT_MODEL", "gpt-5.2")

def make_mcq(language_name: str, target_cefr: str) -> dict:
    """
    Return strict JSON:
    {
      "prompt": "...short context + question...",
      "options": {"A":"...", "B":"...", "C":"...", "D":"..."},
      "correct": "A",
      "explanation": "..."
    }
    """
    prompt = f"""
Create ONE CEFR {target_cefr} placement question for {language_name}.
It must be MIXED: short context (2-3 lines) + reading/vocab/grammar in context.
Multiple-choice with 4 options A-D, exactly one correct.

Return STRICT JSON with keys: prompt, options, correct, explanation.
options must be an object with keys A,B,C,D.
No markdown. No extra keys.
"""
    r = client.responses.create(model=MODEL, input=prompt)
    return json.loads(r.output_text.strip())

def grade_mcq(explanation: str, chosen: str, correct: str) -> dict:
    score = 10 if chosen == correct else 0
    fb = "Correct. " + explanation if chosen == correct else f"Incorrect. Correct answer is {correct}. " + explanation
    return {"score": score, "feedback": fb}

def make_writing_prompt(language_name: str, target_cefr: str) -> dict:
    prompt = f"""
Create ONE writing prompt for a CEFR {target_cefr} placement test in {language_name}.
Return STRICT JSON:
{{"prompt":"...", "min_words":int, "max_words":int}}
No extra keys.
"""
    r = client.responses.create(model=MODEL, input=prompt)
    return json.loads(r.output_text.strip())

def grade_writing(language_name: str, target_cefr: str, prompt_text: str, user_text: str) -> dict:
    """
    Return STRICT JSON:
    {"score": int 0..15, "feedback": "...", "rubric": {"grammar":0..5,"vocab":0..5,"coherence":0..5}}
    """
    prompt = f"""
Grade this writing for a CEFR placement test in {language_name}.
Target level: {target_cefr}

Prompt: {prompt_text}
User text: {user_text}

Use rubric with 3 dimensions (0-5 each): grammar, vocab, coherence.
Total score = 0..15.
Return STRICT JSON with keys: score (int), feedback (string), rubric (object with grammar,vocab,coherence ints).
No markdown. No extra keys.
"""
    r = client.responses.create(model=MODEL, input=prompt)
    data = json.loads(r.output_text.strip())
    data["score"] = int(data["score"])
    return data
