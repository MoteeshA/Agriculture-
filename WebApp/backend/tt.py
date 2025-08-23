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

    def filter_recent_data(self, records, days=7, today_only=False):
        """Filter records to only include data from today or last N days"""
        recent_records = []
        cutoff_date = datetime.now() - timedelta(days=days)

        for record in records:
            if 'Arrival_Date' in record and record['Arrival_Date']:
                try:
                    record_date = datetime.strptime(record['Arrival_Date'], '%d/%m/%Y')

                    if today_only:
                        # Strict filter → only today's data
                        if record_date.date() == datetime.now().date():
                            recent_records.append(record)
                    else:
                        if record_date >= cutoff_date:
                            recent_records.append(record)

                except ValueError:
                    continue

        return recent_records

    def get_state_data(self, state=None, limit=2000, days=None, today_only=False):
        """Fetch and display formatted data for a state with optional day filter"""
        filters = {}
        if state:
            filters["filters[State]"] = state

        status, data = self.fetch_data(filters=filters, limit=limit, sort_by_date=True)

        if status == 200 and 'records' in data and data['records']:
            records = data['records']

            if today_only:
                records = self.filter_recent_data(records, days=0, today_only=True)
            elif days is not None:
                records = self.filter_recent_data(records, days=days)

            if not records:
                print("❌ No records found for the selected filter.")
                return None

            self.display_table(records)
            return records
        else:
            print("❌ No data found")
            return None

    def display_table(self, records):
        """Display output in tabular format"""
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
            print(f"{row['Arrival_Date']:10} {row['State']:12} {row['District']:15} "
                  f"{row['Market']:35} {row['Commodity']:20} "
                  f"{row['Min_Price']:6} {row['Max_Price']:6} {row['Modal_Price']:8}")


def main():
    API_KEY = "579b464db66ec23bdd0000010baed15d539144fa62035eb3cd19e551"
    RESOURCE_ID = "35985678-0d79-46b4-9ed6-6f13308a1d24"

    data_client = DataGovMarketData(API_KEY, RESOURCE_ID)

    print("🌾 Latest Market Price Data 🌾")
    print("=" * 80)

    # Step 1: Ask state
    state_name = input("Enter state name (leave blank for ALL India): ").strip()

    # Step 2: Ask filter choice
    print("\nChoose filter option:")
    print("1. Today's Prices")
    print("2. Last 7 Days")
    print("3. Last 15 Days")
    print("4. All Data (recent first)")
    choice = input("Enter choice (1-4): ").strip()

    # Step 3: Call method with correct filter
    if choice == "1":
        data_client.get_state_data(state=state_name if state_name else None, limit=3000, today_only=True)
    elif choice == "2":
        data_client.get_state_data(state=state_name if state_name else None, limit=3000, days=7)
    elif choice == "3":
        data_client.get_state_data(state=state_name if state_name else None, limit=3000, days=15)
    else:
        data_client.get_state_data(state=state_name if state_name else None, limit=3000, days=None)


if __name__ == "__main__":
    main()
