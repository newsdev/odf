package main

import (
	"encoding/csv"
	"fmt"
	"gopkg.in/mgo.v2"
	"gopkg.in/mgo.v2/bson"
	"log"
	"os"
)

type Event struct {
	Discipline         string      `json:"Discipline" bson:"Discipline"`
	Gender             string      `json:"Gender" bson:"Gender"`
	Event              string      `json:"Event" bson:"Event"`
	Order              interface{} `json:"order" bson:"order"`
	ENGDescription     string      `json:"ENG Description,omitempty" bson:"ENG Description,omitempty"`
	FRADescription     string      `json:"FRA Description,omitempty" bson:"FRA Description,omitempty"`
	PORDescription     string      `json:"POR Description,omitempty" bson:"POR Description,omitempty"`
	ENGLongdescription string      `json:"ENG longdescription,omitempty" bson:"ENG longdescription,omitempty"`
	FRALongdescription string      `json:"FRA longdescription,omitempty" bson:"FRA longdescription,omitempty"`
	PORLongdescription string      `json:"POR longdescription,omitempty" bson:"POR longdescription,omitempty"`
	TeamEvent          interface{} `json:"Team Event" bson:"Team Event"`
}

func ReadCSV() (map[string]Event, error) {
	log.Printf("Opening file")
	CSVLocation := "/tmp/Event.csv"
	reader, err := os.Open(CSVLocation)
	if err != nil {
		log.Printf("Error opening CSV Log file - %s Error: %s", CSVLocation, err)
		return nil, err
	}

	logs := csv.NewReader(reader)

	codes, err := logs.ReadAll()
	if err != nil {
		log.Printf("Error reading entries in CSV file - %s Error: %s", CSVLocation, err)
		return nil, err
	}

	Events := make(map[string]Event)

	for _, entry := range codes {
		if entry[0] == "Discipline" {
			continue
		}

		Events[entry[0]+entry[1]+entry[2]] = Event{
			entry[0],
			entry[1],
			entry[2],
			entry[3],
			entry[4],
			entry[5],
			entry[6],
			entry[7],
			entry[8],
			entry[9],
			entry[10],
		}
	}

	return Events, nil
}

func main() {
	Events, err := ReadCSV()

	if err != nil {
		log.Fatal(err)
	}

	uri := os.Getenv("MONGODB_URI")

	// Validate provided uri.
	_, err = mgo.ParseURL(uri)
	if err != nil {
		log.Fatal(err)
	}

	session, err := mgo.Dial(uri)
	if err != nil {
		log.Fatal(err)
	}

	defer session.Close()

	// Optional. Switch the session to a monotonic behavior.
	session.SetMode(mgo.Monotonic, true)

	c := session.DB("olympics").C("codes_event")
	for _, event := range Events {
		// Update
		log.Println(event.Discipline, event.Gender, event.Event)
		query := bson.M{"Discipline": event.Discipline, "Gender": event.Gender, "Event": event.Event}
		change := bson.M{"$set": event}
		err = c.Update(query, change)
		if err == mgo.ErrNotFound {
			log.Println("Event Code", event.Event, "Not Found. Inserting...")
			err = c.Insert(event)
			if err != nil {
				log.Fatal(err)
			}
		} else if err != nil {
			log.Fatal(err)
		}
	}

	result := []Event{}
	err = c.Find(bson.M{"Event": "000"}).All(&result)
	if err != nil {
		log.Fatal(err)
	}

	fmt.Println("Event Code:", result)
}
