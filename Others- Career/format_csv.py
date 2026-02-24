import pandas as pd
import os

# Input and Output Paths
source_dir = "/Users/naomiivie/Downloads/App/Rings Version 2.1- Multi device Jan 2025"
csv_filename = "Summer_2026_Internships_VERIFIED_OPEN.csv"
xlsx_filename = "Summer_2026_Internships_Formatted.xlsx"

csv_path = os.path.join(source_dir, csv_filename)
output_path = os.path.join(source_dir, xlsx_filename)

try:
    # Read CSV
    df = pd.read_csv(csv_path)
    
    # Create Segments
    # 1. Networking / Alumni
    df_networking = df[df['Category'].str.contains('NETWORKING', na=False, case=False)]
    
    # 2. Closed Roles
    df_closed = df[df['Category'].str.contains('CLOSED', na=False, case=False)]
    
    # 3. Active Internships (Everything else)
    # Exclude rows that are in networking or closed
    df_internships = df[~df.index.isin(df_networking.index) & ~df.index.isin(df_closed.index)]
    
    # Write to Excel with Formatting
    with pd.ExcelWriter(output_path, engine='openpyxl') as writer:
        # Sheet 1: Active Internships
        df_internships.to_excel(writer, sheet_name='Active Internships', index=False)
        
        # Sheet 2: Networking & Alumni
        df_networking.to_excel(writer, sheet_name='Networking & Alumni', index=False)
        
        # Sheet 3: Closed Roles (Reference)
        df_closed.to_excel(writer, sheet_name='Closed Roles', index=False)
        
        # Apply Column Width Formatting
        for sheet in writer.sheets:
            worksheet = writer.sheets[sheet]
            for column_cells in worksheet.columns:
                length = max(len(str(cell.value)) for cell in column_cells)
                # Cap the width at 50 to avoid massive columns
                final_width = min(length + 2, 60)
                worksheet.column_dimensions[column_cells[0].column_letter].width = final_width

    print(f"Successfully converted CSV to Excel at: {output_path}")

except Exception as e:
    print(f"Error converting file: {e}")
