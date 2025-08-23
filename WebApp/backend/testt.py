import requests
import json
import pandas as pd
from datetime import datetime, timedelta


class DataGovMarketData:
    def __init__(self, api_key, resource_id):   # ✅ Fixed constructor
        self.api_key = api_key.strip()
        self.resource_id = resource_id.strip()
        self.base_url = "https://api.data.gov.in/resource"
        self.headers = {"accept": "application/json", "content-type": "application/json"}

    def fetch_data(self, filters=None, limit=100, offset=0, format='json', sort_by_date=True):
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
                params["sort[Arrival_Date]"] = "desc"  # Sort by date descending to get latest first

            if filters:
                params.update(filters)

            response = requests.get(endpoint, headers=self.headers, params=params, timeout=30)

            if response.status_code == 200:
                if format == 'json':
                    return response.status_code, response.json()
                else:
                    return response.status_code, response.text
            else:
                return response.status_code, response.text

        except Exception as e:
            return None, f"Error: {str(e)}"

    def get_latest_data(self, commodity=None, state=None, market=None, limit=20):
        """Get the latest market data with optional filters"""
        print("Fetching latest market data...")

        filters = {}
        if commodity:
            filters["filters[Commodity]"] = commodity
        if state:
            filters["filters[State]"] = state
        if market:
            filters["filters[Market]"] = market

        status, data = self.fetch_data(filters=filters, limit=limit, sort_by_date=True)

        if status == 200 and 'records' in data and data['records']:
            recent_records = self.filter_recent_data(data['records'], days=7)

            if recent_records:
                print(f"✅ Found {len(recent_records)} recent records (last 7 days)")
                self.display_results(recent_records)
                return recent_records
            else:
                print("⚠️ No recent records found (within last 7 days)")
                print("Showing latest available data instead:")
                self.display_results(data['records'][:5])
                return data['records'][:5]
        else:
            print("❌ No records found or error occurred")
            return None

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
                    recent_records.append(record)

        return recent_records

    def get_latest_prices_by_commodity(self, commodity, limit=10):
        """Get latest prices for a specific commodity across markets"""
        print(f"\n🌾 Getting latest prices for {commodity}...")
        return self.get_latest_data(commodity=commodity, limit=limit)

    def get_latest_prices_by_state(self, state, limit=15):
        """Get latest prices across all commodities in a state"""
        print(f"\n📍 Getting latest prices in {state}...")
        return self.get_latest_data(state=state, limit=limit)

    def display_results(self, records):
        """Display results in a readable format with emphasis on recent data"""
        if not records:
            print("No records to display")
            return

        df = pd.DataFrame(records)

        if 'Arrival_Date' in df.columns:
            df['Arrival_Date'] = pd.to_datetime(df['Arrival_Date'], format='%d/%m/%Y', errors='coerce')
            df = df.sort_values('Arrival_Date', ascending=False)

        print("\nMarket Data:")
        print("=" * 100)

        display_cols = ['Arrival_Date', 'State', 'District', 'Market', 'Commodity',
                        'Min_Price', 'Max_Price', 'Modal_Price']

        available_cols = [col for col in display_cols if col in df.columns]

        if available_cols:
            if 'Arrival_Date' in df.columns:
                df['Arrival_Date'] = df['Arrival_Date'].dt.strftime('%Y-%m-%d')
            print(df[available_cols].to_string(index=False))
        else:
            print(df.to_string(index=False))

        if 'Arrival_Date' in df.columns and not df['Arrival_Date'].empty:
            dates = pd.to_datetime(df['Arrival_Date'])
            print(f"\n📅 Date range in data: {dates.min().strftime('%Y-%m-%d')} → {dates.max().strftime('%Y-%m-%d')}")


def main():
    API_KEY = "579b464db66ec23bdd0000010baed15d539144fa62035eb3cd19e551"
    RESOURCE_ID = "35985678-0d79-46b4-9ed6-6f13308a1d24"

    data_client = DataGovMarketData(API_KEY, RESOURCE_ID)

    print("🌾 Latest Market Price Data 🌾")
    print("=" * 50)

    # Common commodities
    commodities = ['Rice', 'Wheat', 'Onion', 'Tomato']

    for commodity in commodities:
        data_client.get_latest_prices_by_commodity(commodity, limit=5)

    print("\n" + "=" * 50)
    print("📍 Latest prices in major states:")

    states = ['Maharashtra', 'Punjab', 'Uttar Pradesh', 'Karnataka']

    for state in states:
        data_client.get_latest_prices_by_state(state, limit=3)


if __name__ == "__main__":
    try:
        import requests
        import pandas as pd
    except ImportError:
        print("Please install required packages:")
        print("pip install requests pandas")
        exit(1)

    main()
