import json
import re
from typing import List, Dict, Any

def generate_tags(title: str, question: str, passage: str) -> List[str]:
    """Generate relevant tags based on title, question, and passage content."""
    text_content = f"{title} {question} {passage}".lower()
    
    # Define tag categories and their keywords
    tag_keywords = {
        "science": ["energy", "ethanol", "fuel", "physics", "chemistry", "biology", "climate", "research"],
        "tax": ["tax", "property", "house tax", "revenue", "government", "municipal"],
        "medical": ["pain", "phantom", "limb", "amputation", "nerve", "sensation", "health", "body"],
        "energy": ["ethanol", "fuel", "energy", "biomass", "fossil", "renewable"],
        "economics": ["economic", "financial", "cost", "unit", "production", "investment"],
        "government": ["government", "law", "policy", "regulation", "state", "federal"],
        "agriculture": ["corn", "sugarcane", "biomass", "grow", "farming", "crop"],
        "brazil": ["brazil", "brazilian"],
        "property": ["property", "real estate", "building", "land", "ownership"],
        "neurology": ["nerve", "brain", "neural", "phantom", "sensation", "neurological"],
        "anatomy": ["limb", "body", "organ", "physical", "amputation", "paralyzed"]
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