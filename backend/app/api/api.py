from fastapi import APIRouter

from .endpoints import analytics, auth, cash_expenses, forecast, model, statements, transactions

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["Authentication"])
api_router.include_router(statements.router, prefix="/statements", tags=["Statements"])
api_router.include_router(transactions.router, prefix="/transactions", tags=["Transactions"])
api_router.include_router(cash_expenses.router, prefix="/cash-expenses", tags=["Cash Expenses"])
api_router.include_router(analytics.router, prefix="/analytics", tags=["Analytics"])
api_router.include_router(forecast.router, prefix="/forecast", tags=["Forecast"])
api_router.include_router(model.router, prefix="/model", tags=["ML Model"])
