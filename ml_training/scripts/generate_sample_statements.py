import os
import random
from datetime import datetime, timedelta
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib import colors
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, PageBreak
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.pdfgen import canvas

BANKS_CONFIG = {
    "HDFC Bank": {
        "color": colors.HexColor("#004c8f"),
        "accent": colors.HexColor("#e6f2fa"),
        "code": "HDFC0001234",
        "branch": "MG Road Branch, Bangalore",
        "account": "50100482910482"
    },
    "State Bank of India": {
        "color": colors.HexColor("#280071"),
        "accent": colors.HexColor("#f0eaf8"),
        "code": "SBIN0004567",
        "branch": "Connaught Place Branch, New Delhi",
        "account": "382910482910"
    },
    "ICICI Bank": {
        "color": colors.HexColor("#8a1e0b"),
        "accent": colors.HexColor("#fdf2f0"),
        "code": "ICIC0009876",
        "branch": "Bandra Kurla Complex Branch, Mumbai",
        "account": "002901582910"
    }
}

SAMPLE_TRANSACTIONS = [
    ("SWIGGY", "UPI/3249820192/SWIGGY/ORDER", 485.00, "DR"),
    ("AMAZON", "POS 48392 AMAZON SELLER IN", 1899.00, "DR"),
    ("UBER", "UPI/987231/UBER INDIA/RIDE", 280.00, "DR"),
    ("BESCOM", "NEFT/ABC ELECTRICITY LTD/98732", 1850.00, "DR"),
    ("NETFLIX", "UPI-NETFLIX-MTHLY-RECURRING", 649.00, "DR"),
    ("DMART", "POS/DMART READY SUPERMARKET", 3420.00, "DR"),
    ("APOLLO", "UPI/APOLLO PHARMACY/MED", 450.00, "DR"),
    ("INDIAN OIL", "POS INDIAN OIL FUEL PUMP", 2200.00, "DR"),
    ("NOBROKER", "NOBROKER RENT TO LANDLORD", 22000.00, "DR"),
    ("AIRTEL", "BILLDESK/AIRTEL BROADBAND", 1179.00, "DR"),
    ("ZOMATO", "UPI/9823012/ZOMATO RESTAURANT", 620.00, "DR"),
    ("FLIPKART", "POS/FLIPKART INTERNET PVT", 2499.00, "DR"),
    ("SPOTIFY", "UPI/SPOTIFY INDIA PREMIUM", 119.00, "DR"),
    ("ZEPTO", "UPI/ZEPTO QUICK GROCERY", 340.00, "DR"),
    ("CULTFIT", "POS CULT FIT GYM MEMBERSHIP", 1500.00, "DR"),
    ("BIGBASKET", "UPI/BIGBASKET GROCERY ORDER", 1850.00, "DR"),
    ("TATA 1MG", "UPI/TATA 1MG HEALTH LAB", 890.00, "DR"),
    ("SHELL", "POS SHELL PETROL PUMP", 2500.00, "DR"),
    ("BOOKMYSHOW", "UPI/BOOKMYSHOW MOVIE TICKETS", 760.00, "DR"),
    ("DOMINOS", "UPI/DOMINOS PIZZA DELIVERY", 580.00, "DR"),
    ("SALARY", "SALARY CREDIT - TECH CORP JAN", 125000.00, "CR"),
    ("INTEREST", "INTEREST CREDIT SB ACCOUNT", 450.00, "CR"),
    ("ATM CASH", "ATM CASH WDL HDFC BANK MG RD", 3000.00, "DR"),
]

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        num_pages = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self.draw_page_number(num_pages)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

    def draw_page_number(self, page_count):
        self.setFont("Helvetica", 8)
        self.setFillColor(colors.gray)
        self.drawRightString(A4[0] - 36, 20, f"Page {self._pageNumber} of {page_count} | ExpenseInsight Verified Statement")


def generate_bank_statement_pdf(
    bank_name: str,
    output_pdf_path: str,
    customer_name: str = "Rahul Sharma",
    start_date: datetime = datetime(2026, 1, 1),
    num_months: int = 6
):
    """Generates a multi-page, realistic 6-month bank statement PDF."""
    os.makedirs(os.path.dirname(os.path.abspath(output_pdf_path)), exist_ok=True)
    
    cfg = BANKS_CONFIG.get(bank_name, BANKS_CONFIG["HDFC Bank"])
    theme_color = cfg["color"]
    accent_color = cfg["accent"]

    doc = SimpleDocTemplate(
        output_pdf_path,
        pagesize=A4,
        rightMargin=30,
        leftMargin=30,
        topMargin=30,
        bottomMargin=35
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'DocTitle',
        parent=styles['Heading1'],
        fontName='Helvetica-Bold',
        fontSize=16,
        textColor=theme_color,
        spaceAfter=4
    )
    subtitle_style = ParagraphStyle(
        'DocSubTitle',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=9,
        textColor=colors.HexColor("#444444"),
        spaceAfter=2
    )
    cell_style = ParagraphStyle(
        'CellText',
        parent=styles['Normal'],
        fontName='Helvetica',
        fontSize=7.5,
        leading=9
    )
    cell_header_style = ParagraphStyle(
        'CellHeader',
        parent=styles['Normal'],
        fontName='Helvetica-Bold',
        fontSize=8,
        textColor=colors.white,
        leading=10
    )

    story = []

    # Bank Header & Account Summary
    end_date = start_date + timedelta(days=num_months * 30)
    
    header_data = [
        [
            Paragraph(f"<b>{bank_name.upper()}</b><br/>{cfg['branch']}<br/>IFSC: {cfg['code']}", subtitle_style),
            Paragraph(f"<b>ACCOUNT STATEMENT</b><br/>Period: {start_date.strftime('%d/%m/%Y')} to {end_date.strftime('%d/%m/%Y')}<br/>Generated: {datetime.now().strftime('%d/%m/%Y')}", subtitle_style)
        ],
        [
            Paragraph(f"<b>Customer Name:</b> {customer_name}<br/><b>Account No:</b> {cfg['account']}<br/><b>Currency:</b> INR (₹)", subtitle_style),
            Paragraph(f"<b>Account Type:</b> Savings Account<br/><b>Branch Code:</b> 0482<br/><b>Status:</b> Active", subtitle_style)
        ]
    ]
    header_table = Table(header_data, colWidths=[260, 275])
    header_table.setStyle(TableStyle([
        ('BACKGROUND', (0,0), (-1,-1), accent_color),
        ('PADDING', (0,0), (-1,-1), 6),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('BOX', (0,0), (-1,-1), 1, theme_color),
        ('LINEBELOW', (0,0), (-1,0), 0.5, colors.HexColor("#cccccc")),
    ]))
    story.append(header_table)
    story.append(Spacer(1, 12))

    # Transactions Table
    table_rows = [
        [
            Paragraph("<b>Date</b>", cell_header_style),
            Paragraph("<b>Narration / Description</b>", cell_header_style),
            Paragraph("<b>Chq/Ref No</b>", cell_header_style),
            Paragraph("<b>Withdrawal (DR)</b>", cell_header_style),
            Paragraph("<b>Deposit (CR)</b>", cell_header_style),
            Paragraph("<b>Balance (₹)</b>", cell_header_style)
        ]
    ]

    current_balance = 85450.00
    current_date = start_date

    # Generate roughly 25-35 transactions per month for 6 months (approx 160-180 rows)
    for m in range(num_months):
        month_start = start_date + timedelta(days=m * 30)
        
        # Monthly Salary on 1st of month
        sal_amount = 125000.00
        current_balance += sal_amount
        sal_ref = f"SAL{month_start.strftime('%Y%m')}{random.randint(1000, 9999)}"
        table_rows.append([
            Paragraph(month_start.strftime("%d/%m/%Y"), cell_style),
            Paragraph(f"SALARY CREDIT - TECH CORP FOR {month_start.strftime('%b %Y').upper()}", cell_style),
            Paragraph(sal_ref, cell_style),
            Paragraph("-", cell_style),
            Paragraph(f"{sal_amount:,.2f}", cell_style),
            Paragraph(f"{current_balance:,.2f}", cell_style),
        ])

        # Monthly Rent on 3rd of month
        rent_date = month_start + timedelta(days=2)
        rent_amt = 22000.00
        current_balance -= rent_amt
        table_rows.append([
            Paragraph(rent_date.strftime("%d/%m/%Y"), cell_style),
            Paragraph("NOBROKER TECHNOLOGIES RENT TO LANDLORD", cell_style),
            Paragraph(f"RENT{random.randint(100000, 999999)}", cell_style),
            Paragraph(f"{rent_amt:,.2f}", cell_style),
            Paragraph("-", cell_style),
            Paragraph(f"{current_balance:,.2f}", cell_style),
        ])

        # Other typical daily/weekly transactions
        for day_offset in range(3, 29, 1):
            if random.random() < 0.75: # ~75% days have a transaction
                txn_date = month_start + timedelta(days=day_offset)
                sample = random.choice(SAMPLE_TRANSACTIONS)
                name_key, desc, amt, cr_dr = sample
                
                # Add slight variance to amount
                varied_amt = round(amt * random.uniform(0.85, 1.25), 2)
                ref_num = f"{random.randint(100000000000, 999999999999)}"

                if cr_dr == "DR":
                    current_balance -= varied_amt
                    dr_str = f"{varied_amt:,.2f}"
                    cr_str = "-"
                else:
                    current_balance += varied_amt
                    dr_str = "-"
                    cr_str = f"{varied_amt:,.2f}"

                table_rows.append([
                    Paragraph(txn_date.strftime("%d/%m/%Y"), cell_style),
                    Paragraph(desc, cell_style),
                    Paragraph(ref_num[:10], cell_style),
                    Paragraph(dr_str, cell_style),
                    Paragraph(cr_str, cell_style),
                    Paragraph(f"{current_balance:,.2f}", cell_style)
                ])

    # Construct ReportLab Table
    col_widths = [55, 215, 65, 65, 65, 70]
    txn_table = Table(table_rows, colWidths=col_widths, repeatRows=1)
    
    t_style = [
        ('BACKGROUND', (0,0), (-1,0), theme_color),
        ('ALIGN', (0,0), (-1,-1), 'LEFT'),
        ('ALIGN', (3,1), (-1,-1), 'RIGHT'),
        ('VALIGN', (0,0), (-1,-1), 'MIDDLE'),
        ('INNERGRID', (0,0), (-1,-1), 0.3, colors.HexColor("#dddddd")),
        ('BOX', (0,0), (-1,-1), 0.8, theme_color),
        ('PADDING', (0,0), (-1,-1), 3),
    ]

    # Alternate row shading
    for r in range(1, len(table_rows)):
        if r % 2 == 0:
            t_style.append(('BACKGROUND', (0, r), (-1, r), colors.HexColor("#fbfbfb")))

    txn_table.setStyle(TableStyle(t_style))
    story.append(txn_table)

    # Build document
    doc.build(story, canvasmaker=NumberedCanvas)
    print(f"Generated sample statement PDF: {output_pdf_path} ({len(table_rows)-1} transactions)")


def generate_all_samples():
    base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "backend", "sample_statements"))
    os.makedirs(base_dir, exist_ok=True)
    
    statements = [
        ("HDFC Bank", os.path.join(base_dir, "HDFC_6_Month_Statement_2026.pdf"), "Rahul Sharma"),
        ("State Bank of India", os.path.join(base_dir, "SBI_6_Month_Statement_2026.pdf"), "Priya Patel"),
        ("ICICI Bank", os.path.join(base_dir, "ICICI_6_Month_Statement_2026.pdf"), "Amit Verma")
    ]

    for bank, path, cust in statements:
        generate_bank_statement_pdf(bank, path, customer_name=cust)

if __name__ == "__main__":
    generate_all_samples()
