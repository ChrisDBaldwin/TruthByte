import json
from typing import Dict, List, Set

def load_analysis_results(filepath: str) -> Dict:
    """Load the tag analysis results."""
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)

def review_categories(suggested_categories: Dict[str, List[str]]) -> Dict[str, List[str]]:
    """Review and clean up keyword categories, removing false positives."""
    
    # More carefully curated categories based on the actual data
    cleaned_categories = {
        "geography": [
            # Clear geographic terms
            "american", "america", "north", "south", "east", "west", "city", "country",
            "canada", "england", "australia", "europe", "european", "ocean", "island",
            "western", "northern", "southern", "eastern", "france", "mexico", "germany",
            "new york", "new york city", "york city", "river", "africa", "japan",
            "india", "mountain", "china", "asia", "regions", "spain", "italy",
            "australian", "lake", "north america", "north american", "continental",
            "northeast", "brazil", "southeast", "japanese", "north carolina", 
            "south america", "ireland", "indian"
        ],
        
        "politics": [
            # Clear political/legal terms
            "states", "state", "law", "laws", "government", "president", "court",
            "constitution", "republic", "illegal", "legal", "political", "senate",
            "tax", "war", "supreme court", "federal", "legislation", "congress",
            "election", "vote", "democracy", "policy", "regulation"
        ],
        
        "entertainment": [
            # Film, TV, books, music, sports entertainment
            "film", "movie", "television", "book", "novel", "story", "drama",
            "episode", "episodes", "season", "seasons", "character", "actor",
            "filming", "production", "sequel", "stars", "drama film", "band",
            "song", "album", "singer", "author", "books", "actors", "music",
            "musical", "films"
        ],
        
        "sports": [
            # Clear sports terms
            "game", "games", "player", "players", "football", "teams", "baseball",
            "sports", "basketball", "league", "soccer", "championship", "championships",
            "fifa", "cup", "world cup", "fifa world", "fifa world cup", "league baseball"
        ],
        
        "science": [
            # Science and technology
            "science", "scientific", "research", "study", "power", "space", "earth",
            "universe", "temperature", "energy", "fuel", "health", "medical",
            "species", "natural", "nature", "plant", "animals", "animal", "biology",
            "physics", "chemistry", "software", "technology", "data"
        ],
        
        "business": [
            # Business and economics
            "company", "business", "production", "market", "bank", "money",
            "cost", "corporation", "industry", "million", "billion", "financial",
            "economic", "investment", "office", "service", "association"
        ],
        
        "history": [
            # Historical terms
            "history", "century", "war", "battle", "empire", "historical",
            "ancient", "world war", "war ii", "world war ii", "20th century"
        ],
        
        "time": [
            # Time-related terms (months, temporal)
            "january", "february", "march", "april", "may", "june", "july",
            "august", "september", "october", "november", "december", "year",
            "years", "early", "later", "current", "former", "originally", "began"
        ],
        
        "general": [
            # Very common, non-specific terms - keep minimal
            "first", "second", "third", "fourth", "one", "two", "three", "four",
            "five", "six", "seven", "new", "old", "large", "small", "high",
            "best", "main", "original", "special", "important", "various",
            "different", "total", "general", "common", "popular", "major"
        ]
    }
    
    return cleaned_categories

def create_enhanced_tag_keywords() -> Dict[str, List[str]]:
    """Create enhanced tag keywords based on analysis and domain knowledge."""
    
    return {
        # Geographic regions and places
        "geography": [
            "america", "american", "united states", "canada", "mexico", "europe", "asia",
            "africa", "australia", "england", "france", "germany", "spain", "italy",
            "japan", "china", "india", "brazil", "russia", "country", "countries",
            "city", "cities", "state", "states", "north", "south", "east", "west",
            "northern", "southern", "eastern", "western", "continent", "ocean",
            "river", "mountain", "island", "lake", "region", "province"
        ],
        
        # Government, politics, law
        "politics": [
            "government", "political", "president", "congress", "senate", "parliament",
            "law", "laws", "legal", "court", "supreme court", "constitution", "federal",
            "election", "vote", "democracy", "republic", "policy", "legislation",
            "regulation", "tax", "taxation", "minister", "governor", "mayor"
        ],
        
        # Military and conflict
        "military": [
            "war", "military", "army", "navy", "air force", "battle", "conflict",
            "soldier", "troops", "weapon", "defense", "attack", "invasion",
            "world war", "civil war", "revolution", "peace", "treaty"
        ],
        
        # Entertainment and media
        "entertainment": [
            "film", "movie", "cinema", "television", "tv", "show", "series",
            "episode", "season", "actor", "actress", "director", "producer",
            "character", "drama", "comedy", "documentary", "music", "song",
            "album", "band", "singer", "musician", "concert", "performance"
        ],
        
        # Literature and books
        "literature": [
            "book", "novel", "author", "writer", "story", "poem", "poetry",
            "literature", "publication", "publisher", "magazine", "newspaper",
            "journal", "article", "text", "writing", "fiction", "non-fiction"
        ],
        
        # Sports and games
        "sports": [
            "sport", "sports", "game", "games", "team", "teams", "player", "players",
            "football", "soccer", "basketball", "baseball", "tennis", "golf",
            "hockey", "olympics", "championship", "tournament", "league", "cup",
            "fifa", "match", "competition", "athlete", "coach", "stadium"
        ],
        
        # Science and technology
        "science": [
            "science", "scientific", "research", "study", "experiment", "theory",
            "technology", "computer", "software", "internet", "digital", "data",
            "physics", "chemistry", "biology", "medicine", "medical", "health",
            "space", "universe", "planet", "earth", "climate", "environment",
            "energy", "power", "nuclear", "solar", "electric"
        ],
        
        # Business and economics
        "business": [
            "business", "company", "corporation", "industry", "market", "economy",
            "economic", "financial", "money", "bank", "investment", "trade",
            "commerce", "profit", "revenue", "cost", "price", "production",
            "manufacturing", "employment", "job", "work", "office", "service"
        ],
        
        # History and time periods
        "history": [
            "history", "historical", "ancient", "medieval", "century", "era",
            "period", "empire", "civilization", "culture", "tradition", "heritage",
            "archaeology", "artifact", "monument", "museum"
        ],
        
        # Education and academia
        "education": [
            "school", "university", "college", "education", "student", "teacher",
            "professor", "academic", "study", "course", "class", "degree",
            "graduation", "learning", "knowledge", "training", "instruction"
        ],
        
        # Religion and philosophy
        "religion": [
            "religion", "religious", "church", "christian", "islam", "muslim",
            "jewish", "judaism", "buddhism", "buddhist", "hinduism", "hindu",
            "god", "faith", "belief", "prayer", "worship", "philosophy",
            "ethical", "moral", "spiritual"
        ],
        
        # Food and cooking
        "food": [
            "food", "eat", "eating", "cook", "cooking", "recipe", "restaurant",
            "kitchen", "meal", "breakfast", "lunch", "dinner", "fruit", "vegetable",
            "meat", "fish", "drink", "water", "coffee", "tea", "wine", "beer"
        ],
        
        # Transportation
        "transport": [
            "transport", "transportation", "car", "automobile", "vehicle", "truck",
            "bus", "train", "plane", "airplane", "ship", "boat", "bicycle",
            "road", "highway", "street", "traffic", "airport", "station", "travel"
        ],
        
        # Animals and nature
        "animals": [
            "animal", "animals", "wildlife", "nature", "natural", "wild", "forest",
            "tree", "plant", "flower", "mammal", "bird", "fish", "insect",
            "species", "habitat", "ecosystem", "conservation", "environment"
        ],
        
        # Health and medicine
        "health": [
            "health", "medical", "medicine", "doctor", "hospital", "patient",
            "disease", "illness", "treatment", "therapy", "surgery", "drug",
            "medication", "vaccine", "virus", "bacteria", "cancer", "heart",
            "brain", "blood", "body", "physical", "mental"
        ]
    }

def save_cleaned_keywords(cleaned_keywords: Dict[str, List[str]], output_file: str):
    """Save the cleaned keywords to a file."""
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(cleaned_keywords, f, indent=2, ensure_ascii=False)

def main():
    """Main function to review and clean keywords."""
    print("Keyword Cleanup Tool")
    print("=" * 30)
    
    # Load original analysis
    try:
        analysis = load_analysis_results("tag_analysis_results.json")
        original_categories = analysis.get("suggested_categories", {})
        
        print(f"Original categories found: {len(original_categories)}")
        for category, keywords in original_categories.items():
            print(f"  {category}: {len(keywords)} keywords")
    
    except FileNotFoundError:
        print("tag_analysis_results.json not found!")
        return
    
    # Create enhanced/cleaned keywords
    print("\nCreating enhanced keyword mappings...")
    cleaned_keywords = create_enhanced_tag_keywords()
    
    print(f"\nCleaned categories: {len(cleaned_keywords)}")
    for category, keywords in cleaned_keywords.items():
        print(f"  {category}: {len(keywords)} keywords")
    
    # Save cleaned version
    output_file = "cleaned_tag_keywords.json"
    save_cleaned_keywords(cleaned_keywords, output_file)
    print(f"\nCleaned keywords saved to: {output_file}")
    
    # Show some examples
    print("\nExample keyword mappings:")
    for category in ["geography", "politics", "entertainment", "sports", "science"]:
        if category in cleaned_keywords:
            keywords = cleaned_keywords[category][:10]  # First 10
            print(f"  {category}: {keywords}")
    
    print(f"\nYou can now use {output_file} to update your add_id_and_tags.py script!")

if __name__ == "__main__":
    main() 