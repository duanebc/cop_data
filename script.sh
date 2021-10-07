# data
# # curl -s https://raw.githubusercontent.com/washingtonpost/data-police-shootings/master/fatal-police-shootings-data.csv
# https://github.com/washingtonpost/data-police-shootings

# json to table
# https://github.com/micha/json-table

convert_data_from_csv_to_json(){
  # https://www.npmjs.com/package/csvtojson
  csvtojson data.csv > data.json
  modify_json_data
}

modify_json_data(){
  jq '
    .[] |
    select(.gender == "M") .gender |= "Male" |
    select(.gender == "F") .gender |= "Female" |
    select(.gender == "") .gender |= "Unknown" |

    select(.race == "W") .race |= "White" |
    select(.race == "B") .race |= "Black" |
    select(.race == "A") .race |= "Asian" |
    select(.race == "N") .race |= "Native American" |
    select(.race == "H") .race |= "Hispanic" |
    select(.race == "O") .race |= "Other" |
    select(.race == "") .race |= "Unknown"
  ' data.json | jq -s '.' > tmp && mv tmp data.json
}

get_years(){
  jq -rM '
    .[] | 
    .date | split("-")[0]
  ' data.json | sort -u
}

get_race_per_year(){
  years=$(get_years)
  for year in $years; do
    jq --arg year "$year" '
      group_by (.race)[] | 
        {
          race: .[0].race, 
          length: length,
          year: $year
        }
    ' data.json
  done | jq -s '.'
}

# https://stackoverflow.com/questions/31035704/use-jq-to-count-on-multiple-levels
rewrite_date_to_year(){
  jq '
    .[] | 
    {
      "id":                       .id,
      "name":                     .name,
      "date":                     (.date | split("-")[0]),
      "manner_of_death":          .manner_of_death,
      "armed":                    .armed,
      "age":                      .age,
      "gender":                   .gender,
      "race":                     .race,
      "city":                     .city,
      "state":                    .state,
      "signs_of_mental_illness":  .signs_of_mental_illness,
      "threat_level":             .threat_level,
      "flee":                     .flee,
      "body_camera":              .body_camera,
      "longitude":                .longitude,
      "latitude":                 .latitude,
      "is_geocoding_exact":       .is_geocoding_exact
    }
  ' data.json | jq -s '.'
}

get_unarmed_race_year(){
  json=$(rewrite_date_to_year)
  years=$(echo "$json" | jq -rM '.[].date' | sort -u)
  for year in $years; do 
    jq --arg year "$year" '
      [
        .[] |
        select( (.armed == "unarmed") and (.date == $year) )
      ] |
      group_by(.date) |
      map({
        (.[0].date): (group_by(.race) | 
          map(
            {
              race:   .[0].race, 
              total:  length,
              date:   .[0].date,
            } 
          ) 
        )
      })[]
    ' <<< "$json" | \
      sed 's/Native American/Native_American/' | \
      jt $year [ race % ] [ total % ] [ date % ] | \
      sort -rn -k 2
  done | column -t | \
    sed 's/Native_American/Native American/'
}

get_unarmed_race_year 
