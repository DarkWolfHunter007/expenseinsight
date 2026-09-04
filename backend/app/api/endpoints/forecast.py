from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ...database.session import get_db
from ...models.db_models import User
from ...models.schemas import ForecastResponse, CategoryForecastDetail
from ...services.forecasting_service import ForecastingService
from ..deps import get_current_user

router = APIRouter()

@router.get("", response_model=ForecastResponse)
def get_forecast(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """
    Generates time-series expense forecasts for next month, 7 days, and 30 days (PRD Sections 27-31).
    """
    service = ForecastingService(db=db)
    return service.generate_user_forecast(user_id=current_user.id, persist=True)


@router.get("/category/{category}", response_model=CategoryForecastDetail)
def get_category_forecast(
    category: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    """Returns predictive spending estimate for a specific category."""
    service = ForecastingService(db=db)
    forecast_data = service.generate_user_forecast(user_id=current_user.id, persist=False)
    
    categories = forecast_data.get("category_forecasts", {})
    # Case-insensitive lookup
    for cat_name, details in categories.items():
        if cat_name.lower() == category.lower():
            return details

    raise HTTPException(
        status_code=404,
        detail=f"Forecast not found for category '{category}'."
    )
