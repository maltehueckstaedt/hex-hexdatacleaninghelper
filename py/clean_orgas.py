import os
import pandas as pd
import openai
from dotenv import load_dotenv
from typing import List
from langchain_openai import OpenAIEmbeddings
from langchain_core.vectorstores import InMemoryVectorStore
from langchain_core.documents import Document
from langchain_core.runnables import chain

# ANSI-Farbcodes für besser lesbare Ausgaben
RESET = "\033[0m"
BOLD = "\033[1m"
GREEN = "\033[92m"
BLUE = "\033[94m"
YELLOW = "\033[93m"
RED = "\033[91m"

# Lade OpenAI API-Key aus der .env Datei
load_dotenv()

# API-Schlüssel abrufen
openai_api_key = os.getenv("OPENAI_API_KEY")

print(f"{BOLD}{GREEN}Starte das Programm...{RESET}")

# Initialisiere OpenAI-Embeddings und Vektorspeicher
embeddings = OpenAIEmbeddings(model="text-embedding-3-large")
vector_store = InMemoryVectorStore(embeddings)

def setup_vector_store(gerit_df):
    """
    Erstellt den Vektorstore für GERIT-Organisationen.
    """
    global vector_store
    print(f"{BOLD}{BLUE}Erstelle Vektorstore für GERIT-Organisationen...{RESET}")
    
    gerit_orgs = gerit_df["Einrichtung"].dropna().unique().tolist()
    docs = [Document(page_content=einrichtung) for einrichtung in gerit_orgs]
    vector_store.add_documents(docs)
    
    print(f"{GREEN}Vektorstore mit {len(docs)} Organisationen erstellt.{RESET}")
    return "Vektorstore wurde erstellt"

@chain
def retriever(query: str) -> List[Document]:
    """
    Sucht nach ähnlichen GERIT-Organisationen für einen gegebenen Namen.
    """
    results = vector_store.similarity_search_with_score(query, k=5)
    docs, scores = zip(*results) if results else ([], [])

    for doc, score in zip(docs, scores):
        doc.metadata["score"] = score  

    return list(docs)

def match_organisations(scraped_df, gerit_df):
    """
    Führt das Matching für Organisationsnamen durch.
    """
    print(f"{BOLD}{BLUE}Starte das Matching von Organisationen...{RESET}")
    
    setup_vector_store(gerit_df)  # Vektorstore mit GERIT-Organisationen befüllen

    # Einzigartige Werte extrahieren
    unique_values = set()
    scraped_df["organisation_names_for_matching_back"] = scraped_df["organisation_names_for_matching_back"].astype(str)
    scraped_df["organisation_names_for_matching_back"].dropna().apply(lambda x: unique_values.update(
        [val.strip() for val in x.split(";") if val.strip() and val.strip().upper() != "NA"]
    ))

    print(f"{BOLD}{YELLOW}Es wurden {len(unique_values)} einzigartige Organisationen gefunden.{RESET}")

    recode_dict = {}
    matching_data = []

    for i, org in enumerate(unique_values):
        if i % 50 == 0:
            print(f"{BOLD}{BLUE}Verarbeite Organisation {i + 1} von {len(unique_values)}...{RESET}")

        orgs = [o.strip() for o in org.split(';')]
        matched_orgs = []
        match_details = []

        for o in orgs:
            match_type = "Keine Übereinstimmung"
            score = None
            matched_value = None

            results = retriever.invoke(o)

            if results and results[0].metadata.get("score", 0) >= 0.65:
                matched_value = results[0].page_content
                score = results[0].metadata["score"]
                match_type = "Fuzzy"
                print(f"{GREEN}Fuzzy Match gefunden: '{o}' → '{matched_value}' (Score: {score:.2f}){RESET}")
            else:
                print(f"{RED}Kein passender Match für '{o}' gefunden.{RESET}")

            matched_orgs.append(matched_value if matched_value else o)
            match_details.append({
                "Ursprünglicher Wert": o,
                "Gematchter GERIT-Wert": matched_value,
                "Matching-Art": match_type,
                "Score": score
            })

        recode_dict[org] = "; ".join([m for m in matched_orgs if m]) if matched_orgs else None
        matching_data.extend(match_details)

    print(f"{BOLD}{BLUE}Matching abgeschlossen. Erstelle DataFrames...{RESET}")

    # Sicherstellen, dass der Index keine Probleme verursacht
    matching_df = pd.DataFrame(matching_data)

    recode_df = pd.DataFrame.from_dict(recode_dict, orient="index", columns=["gerit_organisation"])
    recode_df.index = recode_df.index.astype(str)  # FutureWarning vermeiden
    recode_df.reset_index(inplace=True)
    recode_df.rename(columns={"index": "organisation_names_for_matching_back"}, inplace=True)

    # Merge mit scraped_df
    scraped_df = scraped_df.merge(recode_df, on="organisation_names_for_matching_back", how="left", suffixes=("", "_new"))
    scraped_df = scraped_df.merge(matching_df, left_on="organisation_names_for_matching_back", right_on="Ursprünglicher Wert", how="left", suffixes=("", "_new"))

    for col in ["gerit_organisation", "Score", "Matching-Art"]:
        new_col = col + "_new"
        if new_col in scraped_df.columns:
            scraped_df[col] = scraped_df[new_col]
            scraped_df.drop(columns=[new_col], inplace=True)

    print(f"{BOLD}{GREEN}Matching-Prozess abgeschlossen!{RESET}")

    # 🔥 WICHTIG: Konvertiere None-Werte zu NaN für R-Integration
    scraped_df = scraped_df.where(pd.notna(scraped_df), None)

    # 🔥 Sicherstellen, dass der Index nicht problematisch ist
    scraped_df.reset_index(drop=True, inplace=True)

    return scraped_df