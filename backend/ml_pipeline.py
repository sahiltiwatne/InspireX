import pickle
import re
from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer
from sumy.parsers.plaintext import PlaintextParser
from sumy.nlp.tokenizers import Tokenizer
from sumy.summarizers.text_rank import TextRankSummarizer
from sklearn.metrics.pairwise import cosine_similarity

# Load models
rating_model = pickle.load(open('rating_model.pkl', 'rb'))
tfidf_vectorizer = pickle.load(open('tfidf.pkl', 'rb'))

sim_vectorizer = pickle.load(open('sim_vectorizer.pkl', 'rb'))
tfidf_matrix = pickle.load(open('tfidf_matrix.pkl', 'rb'))
ideas_df = pickle.load(open('ideas_data.pkl', 'rb'))

price_model = pickle.load(open('price_model.pkl', 'rb'))

# Manual stopwords
stop_words = {
    'the','is','in','and','to','of','a','for','on','with',
    'this','that','it','as','an','be','are','was','by','or'
}

# Sentiment analyzer
analyzer = SentimentIntensityAnalyzer()

def clean_text(text):
    text = text.lower()
    text = re.sub(r'[^a-zA-Z]', ' ', text)
    
    words = text.split()
    words = [w for w in words if w not in stop_words]
    
    return " ".join(words)

def get_rating(text):
    text = clean_text(text)
    
    vec = tfidf_vectorizer.transform([text])
    prob = rating_model.predict_proba(vec)[0][1]

    # Convert probability → rating (1–5)
    if prob < 0.1:
        rating = 1
    elif prob < 0.3:
        rating = 2
    elif prob < 0.5:
        rating = 3
    elif prob < 0.7:
        rating = 4
    else:
        rating = 5

    return rating, float(round(prob * 100, 2))

def summarize_text(text):
    if len(text.split()) < 20:
        return text

    try:
        parser = PlaintextParser.from_string(text, Tokenizer("english"))
        summarizer = TextRankSummarizer()

        summary = summarizer(parser.document, 2)
        return " ".join([str(sentence) for sentence in summary])

    except:
        # fallback if tokenizer fails
        return text[:200] + "..."
    
def analyze_sentiment(text):
    scores = analyzer.polarity_scores(text)
    compound = scores['compound']

    if compound >= 0.05:
        sentiment = "Positive"
    elif compound <= -0.05:
        sentiment = "Negative"
    else:
        sentiment = "Neutral"

    return sentiment, float(round(compound, 3))

def find_similar(text, top_n=3):
    text = clean_text(text)
    
    vec = sim_vectorizer.transform([text])
    similarities = cosine_similarity(vec, tfidf_matrix)

    indices = similarities[0].argsort()[-top_n:][::-1]

    results = []
    for idx in indices:
        results.append({
            "idea": ideas_df.iloc[idx]['text'],
            "score": float(round(similarities[0][idx], 3))
        })

    return results

def check_similarity(text):
    results = find_similar(text, top_n=3)
    top_score = results[0]['score']

    if top_score > 0.6:
        status = "High Similarity"
    elif top_score > 0.4:
        status = "Moderate Similarity"
    else:
        status = "Low Similarity"

    return status, results

def extract_features(text, rating):
    text = text.lower()
    
    # Feature 1: rating
    rating_feature = rating
    
    # Feature 2: length
    length_feature = len(text.split())
    
    # Feature 3: complexity
    complex_words = ['ai', 'ml', 'blockchain', 'deep learning', 'automation', 'cloud']
    complexity_feature = sum(1 for word in complex_words if word in text)
    
    return [rating_feature, length_feature, complexity_feature]

def suggest_price(text, rating):
    features = extract_features(text, rating)
    
    base_price = price_model.predict([features])[0]
    
    min_price = int(base_price * 0.8)
    max_price = int(base_price * 1.2)
    
    return {
        "suggested_price": int(base_price),
        "range": f"{min_price} - {max_price}"
    }


def process_idea(text):
    # STEP 1: Rating
    rating, confidence = get_rating(text)
    
    # STEP 2: Summary
    summary = summarize_text(text)
    
    # STEP 3: Sentiment
    sentiment, sentiment_score = analyze_sentiment(text)
    
    # STEP 4: Similar Ideas
    similarity_status, similar_ideas = check_similarity(text)
    
    # STEP 5: Price Suggestion
    price = suggest_price(text, rating)
    
    return {
        "rating": rating,
        "confidence": confidence,
        "summary": summary,
        "sentiment": sentiment,
        "sentiment_score": sentiment_score,
        "similarity_status": similarity_status,
        "similar_ideas": similar_ideas,
        "suggested_price": price["suggested_price"],
        "range": price["range"]
    }

# result = process_idea(
#     "AI powered healthcare app for early disease detection using machine learning and predictive analytics"
# )

# print(result)