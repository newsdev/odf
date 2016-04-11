#!/bin/bash
# usage: `cd scripts;bash mongoimport.sh`
# version number to import codes from, https://github.com/newsdev/odf/tree/master/competitions/OG2016/codes/
_version="12.1"

# file will be downloaded into this folder from s3 bucket
_root="/tmp"

# download file into specified $_root folder
_tar_file="${_version}.common_codes.tar.gz"

# aws path s3://nyt-oly/OG2016/dev/12.0.common_codes.tar.gz
# aws bucket_host/path http://nyt-oly.s3.amazonaws.com/OG2016/dev/12.0.common_codes.tar.gz
# aws public http path http://s3.amazonaws.com/nyt-oly/OG2016/dev/12.0.common_codes.tar.gz
_s3_location="http://s3.amazonaws.com/nyt-oly/OG2016/dev/${_tar_file}"

_full_path="${_root}/${_tar_file}"

echo "Downloading ${_s3_location} into ${_full_path}"
curl -o "${_full_path}" "${_s3_location}"

echo "Extracting csv files from tar into ${_root}"
tar zxf "${_full_path}" -C "${_root}/"

echo "Starting to read ${_root}/*.csv"
_dfiles="${_root}/*.csv"

for f in $_dfiles
do
	echo "Reading `basename "$f"`"
	# initialize both to empty
	_collection=""
	_file=""
	# each file will be imported into its collection
	# should be a better way to do this, for example, rename file names to lowercase and underscores
	case `basename "$f"` in
		"BackgroundReportType.csv")
		_collection="background_report_type"
		_file="$f"
		;;
		"BackgroundSport.csv")
		_collection="background_sport"
		_file="$f"
		;;
		"Cluster.csv")
		_collection="cluster"
		_file="$f"
		;;
		"CompetitionCode.csv")
		_collection="competition_code"
		_file="$f"
		;;
		"Continent.csv")
		_collection="continent"
		_file="$f"
		;;
		"Country.csv")
		_collection="country"
		_file="$f"
		;;
		"Discipline.csv")
		_collection="discipline"
		_file="$f"
		;;
		"DisciplineFunction.csv")
		_collection="discipline_function"
		_file="$f"
		;;
		"DisciplineGender.csv")
		_collection="discipline_gender"
		_file="$f"
		;;
		"Event.csv")
		_collection="event"
		_file="$f"
		;;
		"EventUnit.csv")
		_collection="event_unit"
		_file="$f"
		;;
		"EventUnitType.csv")
		_collection="event_unit_type"
		_file="$f"
		;;
		"FunctionCategory.csv")
		_collection="function_category"
		_file="$f"
		;;
		"HorseBreed.csv")
		_collection="horse_breed"
		_file="$f"
		;;
		"HorseColour.csv")
		_collection="horse_colour"
		_file="$f"
		;;
		"HorseGender.csv")
		_collection="horse_gender"
		_file="$f"
		;;
		"Language.csv")
		_collection="language"
		_file="$f"
		;;
		"Location.csv")
		_collection="location"
		_file="$f"
		;;
		"MaritalStatus.csv")
		_collection="marital_status"
		_file="$f"
		;;
		"NOC.csv")
		_collection="noc"
		_file="$f"
		;;
		"NewsReportType.csv")
		_collection="news_report_type"
		_file="$f"
		;;
		"NewsSport.csv")
		_collection="news_sport"
		_file="$f"
		;;
		"OrgWeb.csv")
		_collection="org_web"
		_file="$f"
		;;
		"Organisation.csv")
		_collection="organisation"
		_file="$f"
		;;
		"ParticipantStatus.csv")
		_collection="participant_status"
		_file="$f"
		;;
		"PersonGender.csv")
		_collection="person_gender"
		_file="$f"
		;;
		"Phase.csv")
		_collection="phase"
		_file="$f"
		;;
		"PhaseType.csv")
		_collection="phase_type"
		_file="$f"
		;;
		"Positions.csv")
		_collection="positions"
		_file="$f"
		;;
		"Record.csv")
		_collection="record"
		_file="$f"
		;;
		"RecordType.csv")
		_collection="record_type"
		_file="$f"
		;;
		"ResultStatus.csv")
		_collection="result_status"
		_file="$f"
		;;
		"ScheduleStatus.csv")
		_collection="schedule_status"
		_file="$f"
		;;
		"SessionType.csv")
		_collection="session_type"
		_file="$f"
		;;
		"Sport.csv")
		_collection="sport"
		_file="$f"
		;;
		"SportCodes.csv")
		_collection="sport_codes"
		_file="$f"
		;;
		"SportGender.csv")
		_collection="sport_gender"
		_file="$f"
		;;
		"Venue.csv")
		_collection="venue"
		_file="$f"
		;;
		"VenueWeatherRegion.csv")
		_collection="venue_weather_region"
		_file="$f"
		;;
		"Version.csv")
		_collection="version"
		_file="$f"
		;;
		"WeatherConditions.csv")
		_collection="weather_conditions"
		_file="$f"
		;;
		"WeatherRegion.csv")
		_collection="weather_region"
		_file="$f"
		;;
		"WebSiteType.csv")
		_collection="website_type"
		_file="$f"
		;;
		"WindDirection.csv")
		_collection="wind_direction"
		_file="$f"
		;;
	esac

	if [ ! -z "$_collection" ] && [ ! -z "$_file" ]; then
		if [ ! -z "$MONGO_HOST" ]; then
			`mongoimport --db olympics --collection codes_"${_collection}" --drop --type csv --headerline --file "${_file}" --host ${MONGO_HOST}:${MONGO_PORT} --username worker --password ${MONGO_PASSWORD}`
		else
			`mongoimport --db olympics --collection codes_"${_collection}" --drop --type csv --headerline --file "${_file}"`
		fi
	fi

	echo "deleting ${_file}"
	rm "${_file}"
done

# cleaning up $_root directory
echo "deleting ${_full_path}"
rm "${_full_path}"
