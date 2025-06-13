"""
Event Collection and DataFrame Management

The EventCollector class provides structured collection of BPF events
into pandas DataFrames for analysis. It manages event callbacks and
data accumulation from BPF ring buffers.
"""

import logging
import threading
from dataclasses import dataclass, field
from typing import Dict, List, Any, Callable

import pandas as pd
from bcc import BPF
from typing import Optional

logger = logging.getLogger(__name__)


class EventCollector:
    """
    Collects BPF events and provides DataFrame conversion

    Accumulates events from BPF ring buffer callbacks and provides
    methods to convert to pandas DataFrame for analysis.
    """

    def __init__(self, schema: Optional[List[str]] = None):
        """
        Initialize empty event collector

        Args:
            schema: List of field names to extract from events. 
                   If None, uses default BPF event fields.
        """
        self._events: List[Dict[str, Any]] = []
        self._columns: set[str] = set()
        self._schema = schema

        logger.debug(f"EventCollector initialized with schema: {self._schema}")

    def add_event(self, event) -> None:
        """
        Add a BPF event to the collection

        Args:
            event: BPF event object with attributes matching the configured schema
        """
        # Extract event attributes to dictionary based on schema
        event_dict = {}

        # Extract fields based on configured schema
        for attr in self._schema:
            if hasattr(event, attr):
                event_dict[attr] = getattr(event, attr)

        # Track all columns we've seen
        self._columns.update(event_dict.keys())

        # Add to collection
        self._events.append(event_dict)
        logger.debug(f"Added event: {event_dict}")

    def to_dataframe(self) -> pd.DataFrame:
        """
        Convert collected events to pandas DataFrame

        Returns:
            DataFrame with one row per event
        """
        if not self._events:
            # Return empty DataFrame with schema columns
            return pd.DataFrame(columns=self._schema)

        df = pd.DataFrame(self._events)
        logger.debug(
            f"Created DataFrame with {len(df)} events and columns: {list(df.columns)}")
        return df

    def clear(self) -> None:
        """Clear all collected events"""
        self._events.clear()
        self._columns.clear()
        logger.debug("Cleared all events")

    def count(self) -> int:
        """Get number of collected events"""
        return len(self._events)

    def create_callback(self, bpf_instance):
        """
        Create a callback function for BPF ring buffer

        Args:
            bpf_instance: BPF instance for event parsing

        Returns:
            Callback function that adds events to this collector
        """
        def callback(ctx, data, size):
            try:
                event = bpf_instance["events"].event(data)
                self.add_event(event)
            except Exception as e:
                logger.error(f"Error processing event: {e}")

        return callback
