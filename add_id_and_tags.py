import json
import re
from typing import List, Dict, Any

def generate_tags(title: str, question: str, passage: str) -> List[str]:
    """Generate relevant tags based on title, question, and passage content."""
    text_content = f"{title} {question} {passage}".lower()
    
    # Define tag categories and their keywords - based on analysis of actual data
    tag_keywords = {
        "geography": [
            "america", "american", "united states", "canada", "mexico", "europe", "asia",
            "africa", "australia", "england", "france", "germany", "spain", "italy",
            "japan", "china", "india", "brazil", "russia", "country", "countries",
            "city", "cities", "state", "states", "north", "south", "east", "west",
            "northern", "southern", "eastern", "western", "continent", "ocean",
            "river", "mountain", "island", "lake", "region", "province"
        ],
        "politics": [
            "government", "political", "president", "congress", "senate", "parliament",
            "law", "laws", "legal", "court", "supreme court", "constitution", "federal",
            "election", "vote", "democracy", "republic", "policy", "legislation",
            "regulation", "tax", "taxation", "minister", "governor", "mayor"
        ],
        "military": [
            "war", "military", "army", "navy", "air force", "battle", "conflict",
            "soldier", "troops", "weapon", "defense", "attack", "invasion",
            "world war", "civil war", "revolution", "peace", "treaty"
        ],
        "entertainment": [
            "film", "movie", "cinema", "television", "tv", "show", "series",
            "episode", "season", "actor", "actress", "director", "producer",
            "character", "drama", "comedy", "documentary", "music", "song",
            "album", "band", "singer", "musician", "concert", "performance"
        ],
        "literature": [
            "book", "novel", "author", "writer", "story", "poem", "poetry",
            "literature", "publication", "publisher", "magazine", "newspaper",
            "journal", "article", "text", "writing", "fiction", "non-fiction"
        ],
        "sports": [
            "sport", "sports", "game", "games", "team", "teams", "player", "players",
            "football", "soccer", "basketball", "baseball", "tennis", "golf",
            "hockey", "olympics", "championship", "tournament", "league", "cup",
            "fifa", "match", "competition", "athlete", "coach", "stadium"
        ],
        "science": [
            "science", "scientific", "research", "study", "experiment", "theory",
            "technology", "computer", "software", "internet", "digital", "data",
            "physics", "chemistry", "biology", "medicine", "medical", "health",
            "space", "universe", "planet", "earth", "climate", "environment",
            "energy", "power", "nuclear", "solar", "electric"
        ],
        "business": [
            "business", "company", "corporation", "industry", "market", "economy",
            "economic", "financial", "money", "bank", "investment", "trade",
            "commerce", "profit", "revenue", "cost", "price", "production",
            "manufacturing", "employment", "job", "work", "office", "service"
        ],
        "history": [
            "history", "historical", "ancient", "medieval", "century", "era",
            "period", "empire", "civilization", "culture", "tradition", "heritage",
            "archaeology", "artifact", "monument", "museum"
        ],
        "education": [
            "school", "university", "college", "education", "student", "teacher",
            "professor", "academic", "study", "course", "class", "degree",
            "graduation", "learning", "knowledge", "training", "instruction"
        ],
        "religion": [
            "religion", "religious", "church", "christian", "islam", "muslim",
            "jewish", "judaism", "buddhism", "buddhist", "hinduism", "hindu",
            "god", "faith", "belief", "prayer", "worship", "philosophy",
            "ethical", "moral", "spiritual"
        ],
        "food": [
            "food", "eat", "eating", "cook", "cooking", "recipe", "restaurant",
            "kitchen", "meal", "breakfast", "lunch", "dinner", "fruit", "vegetable",
            "meat", "fish", "drink", "water", "coffee", "tea", "wine", "beer"
        ],
        "transport": [
            "transport", "transportation", "car", "automobile", "vehicle", "truck",
            "bus", "train", "plane", "airplane", "ship", "boat", "bicycle",
            "road", "highway", "street", "traffic", "airport", "station", "travel"
        ],
        "animals": [
            "animal", "animals", "wildlife", "nature", "natural", "wild", "forest",
            "tree", "plant", "flower", "mammal", "bird", "fish", "insect",
            "species", "habitat", "ecosystem", "conservation", "environment"
        ],
        "health": [
            "health", "medical", "medicine", "doctor", "hospital", "patient",
            "disease", "illness", "treatment", "therapy", "surgery", "drug",
            "medication", "vaccine", "virus", "bacteria", "cancer", "heart",
            "brain", "blood", "body", "physical", "mental"
        ]
    }
    
    # Find matching tags
    tags = []
    for tag, keywords in tag_keywords.items():
        if any(keyword in text_content for keyword in keywords):
            tags.append(tag)
    
    # Ensure at least one tag
    if not tags:
        tags = ["general"]
    
    return tags

def add_id_and_tags(input_file: str, output_file: str):
    """Add id and tags to each entry in the JSONL file."""
    with open(input_file, 'r', encoding='utf-8') as infile, \
         open(output_file, 'w', encoding='utf-8') as outfile:
        
        for line_num, line in enumerate(infile, 1):
            try:
                # Parse JSON entry
                entry = json.loads(line.strip())
                
                # Add unique ID
                entry['id'] = f"q{line_num:03d}"
                
                # Generate and add tags
                title = entry.get('title', '')
                question = entry.get('question', '')
                passage = entry.get('passage', '')
                
                entry['tags'] = generate_tags(title, question, passage)
                
                # Reorder fields: id, tags, question, title, passage, answer
                ordered_entry = {
                    'id': entry['id'],
                    'tags': entry['tags'],
                    'question': entry['question'],
                    'title': entry['title'],
                    'passage': entry['passage'],
                    'answer': entry['answer']
                }
                
                # Write updated entry
                outfile.write(json.dumps(ordered_entry, ensure_ascii=False) + '\n')
                
            except json.JSONDecodeError as e:
                print(f"Error parsing line {line_num}: {e}")
                continue

if __name__ == "__main__":
    input_file = "data/dev.jsonl"
    output_file = "data/dev_with_ids.jsonl"
    
    print("Adding id and tags to dev.jsonl entries...")
    add_id_and_tags(input_file, output_file)
    print(f"Updated file saved as: {output_file}")
    print("Preview of first few entries:")
    
    # Show preview
    with open(output_file, 'r', encoding='utf-8') as f:
        for i, line in enumerate(f):
            if i >= 3:  # Show first 3 entries
                break
            entry = json.loads(line.strip())
            print(f"\nEntry {i+1}:")
            print(f"  ID: {entry['id']}")
            print(f"  Tags: {entry['tags']}")
            print(f"  Question: {entry['question'][:50]}...") 