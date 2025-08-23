import requests
import pandas as pd
from datetime import datetime, timedelta


class DataGovMarketData:
    def __init__(self, api_key, resource_id):
        self.api_key = api_key.strip()
        self.resource_id = resource_id.strip()
        self.base_url = "https://api.data.gov.in/resource"
        self.headers = {"accept": "application/json", "content-type": "application/json"}

    def fetch_data(self, filters=None, limit=2000, offset=0, format='json', sort_by_date=True):
        """Fetch data from the API with option to sort by date"""
        try:
            endpoint = f"{self.base_url}/{self.resource_id}"
            params = {
                "api-key": self.api_key,
                "format": format,
                "limit": limit,
                "offset": offset
            }

            if sort_by_date:
                params["sort[Arrival_Date]"] = "desc"

            if filters:
                params.update(filters)

            response = requests.get(endpoint, headers=self.headers, params=params, timeout=30)

            if response.status_code == 200:
                return response.status_code, response.json()
            else:
                return response.status_code, response.text

        except Exception as e:
            return None, f"Error: {str(e)}"

    def filter_recent_data(self, records, days=7):
        """Filter records to only include data from the last N days"""
        recent_records = []
        cutoff_date = datetime.now() - timedelta(days=days)

        for record in records:
            if 'Arrival_Date' in record and record['Arrival_Date']:
                try:
                    record_date = datetime.strptime(record['Arrival_Date'], '%d/%m/%Y')
                    if record_date >= cutoff_date:
                        recent_records.append(record)
                except ValueError:
                    continue

        return recent_records

    def get_state_data(self, state=None, limit=2000):
        """Fetch and display formatted data for a state or all India"""
        filters = {}
        if state:
            filters["filters[State]"] = state

        status, data = self.fetch_data(filters=filters, limit=limit, sort_by_date=True)

        if status == 200 and 'records' in data and data['records']:
            records = self.filter_recent_data(data['records'], days=7)

            if not records:  # fallback if no recent data
                records = data['records']

            self.display_table(records)
            return records
        else:
            print("❌ No data found")
            return None

    def display_table(self, records):
        """Display output in your requested tabular format"""
        df = pd.DataFrame(records)

        # Pick only important columns
        cols = ['Arrival_Date', 'State', 'District', 'Market', 'Commodity',
                'Min_Price', 'Max_Price', 'Modal_Price']
        df = df[[c for c in cols if c in df.columns]]

        # Convert date
        df['Arrival_Date'] = pd.to_datetime(df['Arrival_Date'], format='%d/%m/%Y', errors='coerce')
        df = df.sort_values('Arrival_Date', ascending=False)

        # Format date back
        df['Arrival_Date'] = df['Arrival_Date'].dt.strftime('%Y-%m-%d')

        # Print line by line like your example
        for _, row in df.iterrows():
            print(f"{row['Arrival_Date']:10} {row['State']:10} {row['District']:15} "
                  f"{row['Market']:35} {row['Commodity']:20} "
                  f"{row['Min_Price']:6} {row['Max_Price']:6} {row['Modal_Price']:8}")


def main():
    API_KEY = "579b464db66ec23bdd0000010baed15d539144fa62035eb3cd19e551"
    RESOURCE_ID = "35985678-0d79-46b4-9ed6-6f13308a1d24"

    data_client = DataGovMarketData(API_KEY, RESOURCE_ID)

    print("🌾 Latest Market Price Data 🌾")
    print("=" * 80)

    # Ask user input
    state_name = input("Enter state name (leave blank for ALL India): ").strip()

    data_client.get_state_data(state=state_name if state_name else None, limit=3000)


if __name__ == "__main__":
    main()
